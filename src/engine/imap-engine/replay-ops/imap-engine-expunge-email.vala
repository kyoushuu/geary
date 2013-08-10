/* Copyright 2012-2013 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

private class Geary.ImapEngine.ExpungeEmail : Geary.ImapEngine.SendReplayOperation {
    private GenericFolder engine;
    private Gee.List<ImapDB.EmailIdentifier> to_remove = new Gee.ArrayList<ImapDB.EmailIdentifier>();
    private Cancellable? cancellable;
    private Gee.Set<ImapDB.EmailIdentifier>? removed_ids = null;
    private int original_count = 0;
    
    public ExpungeEmail(GenericFolder engine, Gee.List<ImapDB.EmailIdentifier> to_remove,
        Cancellable? cancellable = null) {
        base("ExpungeEmail");
        
        this.engine = engine;
        
        this.to_remove.add_all(to_remove);
        this.cancellable = cancellable;
    }
    
    public override async ReplayOperation.Status replay_local_async() throws Error {
        if (to_remove.size <= 0)
            return ReplayOperation.Status.COMPLETED;
        
        int remote_count;
        int last_seen_remote_count;
        original_count = engine.get_remote_counts(out remote_count, out last_seen_remote_count);
        
        // because this value is only used for reporting count changes, offer best-possible service
        if (original_count < 0)
            original_count = to_remove.size;
        
        removed_ids = yield engine.local_folder.mark_removed_async(to_remove, true, cancellable);
        if (removed_ids == null || removed_ids.size == 0)
            return ReplayOperation.Status.COMPLETED;
        
        engine.notify_email_removed(removed_ids);
        
        engine.notify_email_count_changed(Numeric.int_floor(original_count - removed_ids.size, 0),
            Geary.Folder.CountChangeReason.REMOVED);
        
        return ReplayOperation.Status.CONTINUE;
    }
    
    public override bool query_local_writebehind_operation(ReplayOperation.WritebehindOperation op,
        EmailIdentifier id, Imap.EmailFlags? flags) {
        ImapDB.EmailIdentifier? imapdb_id = id as ImapDB.EmailIdentifier;
        if (imapdb_id == null)
            return true;
        
        if (!removed_ids.contains(imapdb_id))
            return true;
        
        switch (op) {
            case ReplayOperation.WritebehindOperation.CREATE:
                // don't allow for the message to be created, it will be removed on the server by
                // this operation
                return false;
            
            case ReplayOperation.WritebehindOperation.REMOVE:
                // removed locally, to be removed remotely, don't bother writing locally
                return false;
            
            default:
                // ignored
                return true;
        }
    }
    
    public override async ReplayOperation.Status replay_remote_async() throws Error {
        Gee.Set<Imap.UID>? uids = yield engine.local_folder.get_uids_async(removed_ids,
            ImapDB.Folder.ListFlags.INCLUDE_MARKED_FOR_REMOVE, cancellable);
        
        if (uids != null && uids.size > 0) {
            // Remove from server. Note that this causes the receive replay queue to kick into
            // action, removing the e-mail but *NOT* firing a signal; the "remove marker" indicates
            // that the signal has already been fired.
            yield engine.remote_folder.remove_email_async(
                new Imap.MessageSet.uid_sparse(uids.to_array()), cancellable);
        }
        
        return ReplayOperation.Status.COMPLETED;
    }
    
    public override async void backout_local_async() throws Error {
        yield engine.local_folder.mark_removed_async(removed_ids, false, cancellable);
        
        engine.notify_email_appended(removed_ids);
        engine.notify_email_count_changed(original_count, Geary.Folder.CountChangeReason.APPENDED);
    }
    
    public override string describe_state() {
        return "to_remove=%d".printf(to_remove.size);
    }
}

