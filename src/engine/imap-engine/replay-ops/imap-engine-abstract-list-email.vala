/* Copyright 2012-2013 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

private abstract class Geary.ImapEngine.AbstractListEmail : Geary.ImapEngine.SendReplayOperation {
    private class RemoteBatchOperation : Nonblocking.BatchOperation {
        // IN
        public GenericFolder owner;
        public Imap.MessageSet msg_set;
        public Geary.Email.Field unfulfilled_fields;
        public Geary.Email.Field required_fields;
        
        // OUT
        public Gee.Set<Geary.EmailIdentifier> created_ids = new Gee.HashSet<Geary.EmailIdentifier>();
        
        public RemoteBatchOperation(GenericFolder owner, Imap.MessageSet msg_set,
            Geary.Email.Field unfulfilled_fields, Geary.Email.Field required_fields) {
            this.owner = owner;
            this.msg_set = msg_set;
            this.unfulfilled_fields = unfulfilled_fields;
            this.required_fields = required_fields;
        }
        
        public override async Object? execute_async(Cancellable? cancellable) throws Error {
            // fetch from remote folder
            Gee.List<Geary.Email>? list = yield owner.remote_folder.list_email_async(msg_set,
                unfulfilled_fields, cancellable);
            if (list == null || list.size == 0)
                return null;
            
            // TODO: create_or_merge_email_async() should only write if something has changed
            Gee.Map<Geary.Email, bool> created_or_merged = yield owner.local_folder.create_or_merge_email_async(
                list, cancellable);
            for (int ctr = 0; ctr < list.size; ctr++) {
                Geary.Email email = list[ctr];
                
                // if created, add to id pool
                if (created_or_merged.get(email))
                    created_ids.add(email.id);
                
                // if remote email doesn't fulfills all required fields, fetch full and return that
                // TODO: Need a sparse ID fetch in ImapDB.Folder to do this all at once
                if (!email.fields.fulfills(required_fields)) {
                    email = yield owner.local_folder.fetch_email_async((ImapDB.EmailIdentifier) email.id,
                        required_fields, ImapDB.Folder.ListFlags.NONE, cancellable);
                    list[ctr] = email;
                }
            }
            
            return list;
        }
    }
    
    protected GenericFolder owner;
    protected Geary.Email.Field required_fields;
    protected Gee.List<Geary.Email>? accumulator = null;
    protected weak EmailCallback? cb;
    protected Cancellable? cancellable;
    protected Folder.ListFlags flags;
    protected Gee.HashMultiMap<Geary.Email.Field, ImapDB.EmailIdentifier> unfulfilled
        = new Gee.HashMultiMap<Geary.Email.Field, ImapDB.EmailIdentifier>();
    
    public AbstractListEmail(string name, GenericFolder owner, Geary.Email.Field required_fields,
        Folder.ListFlags flags, Gee.List<Geary.Email>? accumulator, EmailCallback? cb,
        Cancellable? cancellable) {
        base(name);
        
        this.owner = owner;
        this.required_fields = required_fields;
        this.accumulator = accumulator;
        this.cb = cb;
        this.cancellable = cancellable;
        this.flags = flags;
    }
    
    public override void notify_remote_removed_during_normalization(Gee.Collection<ImapDB.EmailIdentifier> ids) {
        // remove email already picked up from local store ... for email reported via the
        // callback, too late
        if (accumulator != null) {
            Collection.remove_if<Geary.Email>(accumulator, (email) => {
                return ids.contains((ImapDB.EmailIdentifier) email.id);
            });
        }
        
        // remove from unfulfilled list, as there's nothing to fetch from the server
        // this funky little loop ensures that all mentions of the EmailIdentifier in
        // the unfulfilled MultiMap are removed, but must restart loop because removing
        // within a foreach invalidates the Iterator
        foreach (Geary.EmailIdentifier id in ids) {
            bool removed = false;
            do {
                removed = false;
                foreach (Geary.Email.Field field in unfulfilled.get_keys()) {
                    removed = unfulfilled.remove(field, (ImapDB.EmailIdentifier) id);
                    if (removed)
                        break;
                }
            } while (removed);
        }
    }
    
    // Child class should execute its own calls *before* calling this base method
    public override async ReplayOperation.Status replay_remote_async() throws Error {
        // only deal with unfulfilled email, child class must deal with everything else
        if (unfulfilled.size == 0)
            return ReplayOperation.Status.COMPLETED;
        
        // schedule operations to remote for each set of email with unfulfilled fields and merge
        // in results, pulling out the entire email
        Nonblocking.Batch batch = new Nonblocking.Batch();
        foreach (Geary.Email.Field unfulfilled_fields in unfulfilled.get_keys()) {
            Gee.Collection<ImapDB.EmailIdentifier> email_ids = unfulfilled.get(unfulfilled_fields);
            if (email_ids.size == 0)
                continue;
            
            // If we just became aware of these messages, we won't have their
            // ID recorded in the database, so we assume we can just use the
            // UID as seen in the EmailIdentifier.
            Gee.HashSet<Imap.UID> uids = new Gee.HashSet<Imap.UID>();
            Gee.HashSet<ImapDB.EmailIdentifier> need_uids = new Gee.HashSet<ImapDB.EmailIdentifier>();
            foreach (Geary.ImapDB.EmailIdentifier id in email_ids) {
                if (id.message_id == Db.INVALID_ROWID) {
                    assert(id.uid != null);
                    uids.add(id.uid);
                } else {
                    need_uids.add(id);
                }
            }
            
            Gee.Set<Imap.UID>? got_uids = yield owner.local_folder.get_uids_async(
                need_uids, ImapDB.Folder.ListFlags.NONE, cancellable);
            if (got_uids != null)
                uids.add_all(got_uids);
            
            if (uids.size == 0)
                continue;
            
            Imap.MessageSet msg_set = new Imap.MessageSet.uid_sparse(uids.to_array());
            RemoteBatchOperation remote_op = new RemoteBatchOperation(owner, msg_set, unfulfilled_fields,
                required_fields);
            batch.add(remote_op);
        }
        
        yield batch.execute_all_async(cancellable);
        batch.throw_first_exception();
        
        Gee.ArrayList<Geary.Email> result_list = new Gee.ArrayList<Geary.Email>();
        Gee.HashSet<Geary.EmailIdentifier> created_ids = new Gee.HashSet<Geary.EmailIdentifier>();
        foreach (int batch_id in batch.get_ids()) {
            Gee.List<Geary.Email>? list = (Gee.List<Geary.Email>?) batch.get_result(batch_id);
            if (list != null && list.size > 0) {
                result_list.add_all(list);
                
                RemoteBatchOperation op = (RemoteBatchOperation) batch.get_operation(batch_id);
                created_ids.add_all(op.created_ids);
            }
        }
        
        // report merged emails
        if (result_list.size > 0) {
            if (accumulator != null)
                accumulator.add_all(result_list);
            
            if (cb != null)
                cb(result_list, null);
        }
        
        // done
        if (cb != null)
            cb(null, null);
        
        // signal
        if (created_ids.size > 0)
            owner.notify_email_discovered(created_ids);
        
        return ReplayOperation.Status.COMPLETED;
    }
    
    protected async Trillian is_fully_expanded_async() throws Error {
        int remote_count;
        owner.get_remote_counts(out remote_count, null);
        
        // if unknown (unconnected), say so
        if (remote_count < 0)
            return Trillian.UNKNOWN;
        
        // include marked for removed in the count in case this is being called while a removal
        // is in process, in which case don't want to expand vector this moment because the
        // vector is in flux
        int local_count_with_marked = yield owner.local_folder.get_email_count_async(
            ImapDB.Folder.ListFlags.INCLUDE_MARKED_FOR_REMOVE, cancellable);
        
        return Trillian.from_boolean(local_count_with_marked >= remote_count);
    }
    
    // Adds everything in the expansion to the unfulfilled set with required_fields plus ImapDB's
    // field requirements
    protected async void expand_vector_async(Imap.UID? initial_uid, int count) throws Error {
        // watch out for situations where the entire folder is represented locally (i.e. no
        // expansion necessary)
        int remote_count = owner.get_remote_counts(null, null);
        if (remote_count < 0)
            return;
        
        // include marked for removed in the count in case this is being called while a removal
        // is in process, in which case don't want to expand vector this moment because the
        // vector is in flux
        int local_count = yield owner.local_folder.get_email_count_async(
            ImapDB.Folder.ListFlags.NONE, cancellable);
        
        // determine low and high position for expansion ... default in most code paths for high
        // is the SequenceNumber just below the lowest known message, unless no local messages
        // are present
        Imap.SequenceNumber? low_pos = null;
        Imap.SequenceNumber? high_pos = null;
        if (local_count > 0)
            high_pos = new Imap.SequenceNumber(Numeric.int_floor(remote_count - local_count, 1));
        
        if (flags.is_oldest_to_newest()) {
            if (initial_uid == null) {
                // if oldest to newest and initial-id is null, then start at the bottom
                low_pos = new Imap.SequenceNumber(1);
            } else {
                Gee.Map<Imap.UID, Imap.SequenceNumber>? map = yield owner.remote_folder.uid_to_position_async(
                    new Imap.MessageSet.uid(initial_uid), cancellable);
                if (map == null || map.size == 0 || !map.has_key(initial_uid)) {
                    debug("%s: Unable to expand vector for initial_uid=%s: unable to convert to position",
                        to_string(), initial_uid.to_string());
                    
                    return;
                }
                
                low_pos = map.get(initial_uid);
            }
        } else {
            // newest to oldest
            //
            // if initial_id is null or no local earliest UID, then vector expansion is simple:
            // merely count backwards from the top of the vector
            if (initial_uid == null || local_count == 0) {
                low_pos = new Imap.SequenceNumber(Numeric.int_floor((remote_count - count) + 1, 1));
                
                // don't set high_pos, leave null to use symbolic "highest" in MessageSet
                high_pos = null;
            } else {
                // not so simple; need to determine the *remote* position of the earliest local
                // UID and count backward from that; if no UIDs present, then it's as if no initial_id
                // is specified.
                //
                // low position: count backwards; note that it's possible this will overshoot and
                // pull in more email than technically required, but without a round-trip to the
                // server to determine the position number of a particular UID, this makes sense
                assert(high_pos != null);
                low_pos = new Imap.SequenceNumber(
                    Numeric.int_floor((high_pos.value - count) + 1, 1));
            }
        }
        
        // low_pos must be defined by this point
        assert(low_pos != null);
        
        if (high_pos != null && low_pos.value > high_pos.value) {
            debug("%s: Aborting vector expansion, low_pos=%s > high_pos=%s", owner.to_string(),
                low_pos.to_string(), high_pos.to_string());
            
            return;
        }
        
        Imap.MessageSet msg_set;
        int actual_count = -1;
        if (high_pos != null) {
            msg_set = new Imap.MessageSet.range_by_first_last(low_pos, high_pos);
            actual_count = (high_pos.value - low_pos.value) + 1;
        } else {
            msg_set = new Imap.MessageSet.range_to_highest(low_pos);
        }
        
        debug("%s: Performing vector expansion using %s for initial_uid=%s count=%d actual_count=%d",
            owner.to_string(), msg_set.to_string(),
            (initial_uid != null) ? initial_uid.to_string() : "(null)", count, actual_count);
        
        Gee.List<Geary.Email>? list = yield owner.remote_folder.list_email_async(msg_set,
            Geary.Email.Field.NONE, cancellable);
        if (list != null) {
            // add all the new email to the unfulfilled list, which ensures (when replay_remote_async
            // is called) that the fields are downloaded and added to the database
            foreach (Geary.Email email in list) {
                unfulfilled.set(required_fields | ImapDB.Folder.REQUIRED_FIELDS,
                    (ImapDB.EmailIdentifier) email.id);
            }
        }
        
        debug("%s: Vector expansion completed (%d new email)", owner.to_string(),
            (list != null) ? list.size : 0);
    }
    
    public override async void backout_local_async() throws Error {
        // R/O, no backout
    }
    
    public override string describe_state() {
        return "required_fields=%Xh local_only=%s force_update=%s".printf(required_fields,
            flags.is_local_only().to_string(), flags.is_force_update().to_string());
    }
}

