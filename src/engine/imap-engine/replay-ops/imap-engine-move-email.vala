/* Copyright 2012-2013 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

private class Geary.ImapEngine.MoveEmail : Geary.ImapEngine.SendReplayOperation {
    private GenericFolder engine;
    private Gee.List<ImapDB.EmailIdentifier> to_move = new Gee.ArrayList<ImapDB.EmailIdentifier>();
    private Geary.FolderPath destination;
    private Cancellable? cancellable;
    private Gee.Set<ImapDB.EmailIdentifier>? moved_ids = null;
    private int original_count = 0;

    public MoveEmail(GenericFolder engine, Gee.List<ImapDB.EmailIdentifier> to_move, 
        Geary.FolderPath destination, Cancellable? cancellable = null) {
        base("MoveEmail");

        this.engine = engine;

        this.to_move.add_all(to_move);
        this.destination = destination;
        this.cancellable = cancellable;
    }

    public override async ReplayOperation.Status replay_local_async() throws Error {
        if (to_move.size <= 0)
            return ReplayOperation.Status.COMPLETED;
        
        int remote_count;
        int last_seen_remote_count;
        original_count = engine.get_remote_counts(out remote_count, out last_seen_remote_count);
        
        // as this value is only used for reporting, offer best-possible service
        if (original_count < 0)
            original_count = to_move.size;
        
        moved_ids = yield engine.local_folder.mark_removed_async(to_move, true, cancellable);
        if (moved_ids == null || moved_ids.size == 0)
            return ReplayOperation.Status.COMPLETED;
        
        engine.notify_email_removed(moved_ids);
        
        engine.notify_email_count_changed(Numeric.int_floor(original_count - to_move.size, 0),
            Geary.Folder.CountChangeReason.REMOVED);
        
        return ReplayOperation.Status.CONTINUE;
    }
    
    public override void notify_remote_removed_during_normalization(Gee.Collection<ImapDB.EmailIdentifier> ids) {
        // don't bother updating on server or backing out locally
        moved_ids.remove_all(ids);
    }
    
    public override async ReplayOperation.Status replay_remote_async() throws Error {
        if (moved_ids.size > 0) {
            yield engine.remote_folder.move_email_async(
                new Imap.MessageSet.uid_sparse(ImapDB.EmailIdentifier.to_uids(moved_ids).to_array()),
                destination, cancellable);
        }
        
        return ReplayOperation.Status.COMPLETED;
    }

    public override async void backout_local_async() throws Error {
        yield engine.local_folder.mark_removed_async(moved_ids, false, cancellable);
        
        engine.notify_email_appended(moved_ids);
        engine.notify_email_count_changed(original_count, Geary.Folder.CountChangeReason.APPENDED);
    }

    public override string describe_state() {
        return "%d email IDs to %s".printf(to_move.size, destination.to_string());
    }
}

