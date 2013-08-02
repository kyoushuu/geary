/* Copyright 2013 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

public class Geary.App.EmailStore : BaseObject {
    // TODO: move these out into separate files.
    private abstract class AsyncFolderOperation : BaseObject {
        public abstract Type folder_type { get; }
        public virtual Geary.FolderPath? restrict_to_folder { get { return null; } }
        public abstract async Gee.Collection<Geary.EmailIdentifier> exec_async(
            Geary.Folder folder, Gee.Collection<Geary.EmailIdentifier> ids,
            Cancellable? cancellable) throws Error;
    }
    
    private class ListOperation : AsyncFolderOperation {
        public override Type folder_type { get { return typeof(Geary.Folder); } }
        
        public Gee.HashSet<Geary.Email> results;
        public Geary.Email.Field required_fields;
        public Geary.Folder.ListFlags flags;
        
        public ListOperation(Geary.Email.Field required_fields, Geary.Folder.ListFlags flags) {
            results = new Gee.HashSet<Geary.Email>();
            this.required_fields = required_fields;
            this.flags = flags;
        }
        
        public override async Gee.Collection<Geary.EmailIdentifier> exec_async(
            Geary.Folder folder, Gee.Collection<Geary.EmailIdentifier> ids,
            Cancellable? cancellable) throws Error {
            // TODO: catch/ignore/save certain exceptions?
            results.add_all(yield folder.list_email_by_sparse_id_async(
                ids, required_fields, flags, cancellable));
            return ids;
        }
    }
    
    private class FetchOperation : AsyncFolderOperation {
        public override Type folder_type { get { return typeof(Geary.Folder); } }
        
        public Geary.Email? result = null;
        public Geary.Email.Field required_fields;
        public Geary.Folder.ListFlags flags;
        
        public FetchOperation(Geary.Email.Field required_fields, Geary.Folder.ListFlags flags) {
            this.required_fields = required_fields;
            this.flags = flags;
        }
        
        public override async Gee.Collection<Geary.EmailIdentifier> exec_async(
            Geary.Folder folder, Gee.Collection<Geary.EmailIdentifier> ids,
            Cancellable? cancellable) throws Error {
            assert(result == null);
            Geary.EmailIdentifier? id = Geary.Collection.get_first(ids);
            assert(id != null);
            
            // TODO: catch/ignore/save certain exceptions?
            result = yield folder.fetch_email_async(
                id, required_fields, flags, cancellable);
            return new Geary.Collection.SingleItem<Geary.EmailIdentifier>(id);
        }
    }
    
    private class MarkOperation : AsyncFolderOperation {
        public override Type folder_type { get { return typeof(Geary.FolderSupport.Mark); } }
        
        public Geary.EmailFlags? flags_to_add;
        public Geary.EmailFlags? flags_to_remove;
        
        public MarkOperation(Geary.EmailFlags? flags_to_add, Geary.EmailFlags? flags_to_remove) {
            this.flags_to_add = flags_to_add;
            this.flags_to_remove = flags_to_remove;
        }
        
        public override async Gee.Collection<Geary.EmailIdentifier> exec_async(
            Geary.Folder folder, Gee.Collection<Geary.EmailIdentifier> ids,
            Cancellable? cancellable) throws Error {
            Geary.FolderSupport.Mark? mark = folder as Geary.FolderSupport.Mark;
            assert(mark != null);
            
            Gee.List<Geary.EmailIdentifier> list
                = Geary.Collection.to_array_list<Geary.EmailIdentifier>(ids);
            // TODO: catch/ignore/save certain exceptions?
            yield mark.mark_email_async(list, flags_to_add, flags_to_remove, cancellable);
            return ids;
        }
    }
    
    private class CopyOperation : AsyncFolderOperation {
        public override Type folder_type { get { return typeof(Geary.FolderSupport.Copy); } }
        
        public Geary.FolderPath destination;
        
        public CopyOperation(Geary.FolderPath destination) {
            this.destination = destination;
        }
        
        public override async Gee.Collection<Geary.EmailIdentifier> exec_async(
            Geary.Folder folder, Gee.Collection<Geary.EmailIdentifier> ids,
            Cancellable? cancellable) throws Error {
            Geary.FolderSupport.Copy? copy = folder as Geary.FolderSupport.Copy;
            assert(copy != null);
            
            Gee.List<Geary.EmailIdentifier> list
                = Geary.Collection.to_array_list<Geary.EmailIdentifier>(ids);
            // TODO: catch/ignore/save certain exceptions?
            yield copy.copy_email_async(list, destination, cancellable);
            return ids;
        }
    }
    
    private class MoveOperation : AsyncFolderOperation {
        public override Type folder_type { get { return typeof(Geary.FolderSupport.Move); } }
        public override Geary.FolderPath? restrict_to_folder { get { return origin; } }
        
        public Geary.FolderPath origin;
        public Geary.FolderPath destination;
        
        public MoveOperation(Geary.FolderPath origin, Geary.FolderPath destination) {
            this.origin = origin;
            this.destination = destination;
        }
        
        public override async Gee.Collection<Geary.EmailIdentifier> exec_async(
            Geary.Folder folder, Gee.Collection<Geary.EmailIdentifier> ids,
            Cancellable? cancellable) throws Error {
            Geary.FolderSupport.Move? move = folder as Geary.FolderSupport.Move;
            assert(move != null);
            
            Gee.List<Geary.EmailIdentifier> list
                = Geary.Collection.to_array_list<Geary.EmailIdentifier>(ids);
            // TODO: catch/ignore/save certain exceptions?
            yield move.move_email_async(list, destination, cancellable);
            return ids;
        }
    }
    
    public Geary.Account account { get; private set; }
    
    public EmailStore(Geary.Account account) {
        this.account = account;
    }
    
    /**
     * Lists any set of EmailIdentifiers as if they were all in one folder.
     */
    public async Gee.Collection<Geary.Email>? list_email_by_sparse_id_async(
        Gee.Collection<Geary.EmailIdentifier> emails, Geary.Email.Field required_fields,
        Geary.Folder.ListFlags flags, Cancellable? cancellable = null) throws Error {
        ListOperation op = new ListOperation(required_fields, flags);
        yield do_folder_operation_async(op, emails, cancellable);
        return (op.results.size > 0 ? op.results : null);
    }
    
    /**
     * Fetches any EmailIdentifier regardless of what folder it's in.
     */
    public async Geary.Email fetch_email_async(Geary.EmailIdentifier email_id,
        Geary.Email.Field required_fields, Geary.Folder.ListFlags flags,
        Cancellable? cancellable = null) throws Error {
        FetchOperation op = new FetchOperation(required_fields, flags);
        yield do_folder_operation_async(op,
            new Geary.Collection.SingleItem<Geary.EmailIdentifier>(email_id), cancellable);
        
        assert(op.result != null);
        return op.result;
    }
    
    /**
     * Marks any set of EmailIdentifiers as if they were all in one
     * Geary.FolderSupport.Mark folder.
     */
    public async void mark_email_async(Gee.Collection<Geary.EmailIdentifier> emails,
        Geary.EmailFlags? flags_to_add, Geary.EmailFlags? flags_to_remove,
        Cancellable? cancellable = null) throws Error {
        yield do_folder_operation_async(new MarkOperation(flags_to_add, flags_to_remove),
            emails, cancellable);
    }
    
    /**
     * Copies any set of EmailIdentifiers as if they were all in one
     * Geary.FolderSupport.Copy folder.
     */
    public async void copy_email_async(Gee.Collection<Geary.EmailIdentifier> emails,
        Geary.FolderPath destination, Cancellable? cancellable = null) throws Error {
        yield do_folder_operation_async(new CopyOperation(destination),
            emails, cancellable);
    }
    
    /**
     * Moves any set of EmailIdentifiers as if they were all in one
     * Geary.FolderSupport.Move folder.
     */
    public async void move_email_async(Gee.Collection<Geary.EmailIdentifier> emails,
        Geary.FolderPath origin, Geary.FolderPath destination,
        Cancellable? cancellable = null) throws Error {
        yield do_folder_operation_async(new MoveOperation(origin, destination),
            emails, cancellable);
    }
    
    private async Gee.HashMap<Geary.FolderPath, Geary.Folder> get_folder_instances_async(
        Gee.Collection<Geary.FolderPath> paths, Cancellable? cancellable) throws Error {
        Gee.HashMap<Geary.FolderPath, Geary.Folder> folders
            = new Gee.HashMap<Geary.FolderPath, Geary.Folder>();
        foreach (Geary.FolderPath path in paths) {
            // TODO: can this be cached or something?
            Geary.Folder folder = yield account.fetch_folder_async(path, cancellable);
            folders.set(path, folder);
        }
        return folders;
    }
    
    private Geary.FolderPath? next_folder_for_operation(AsyncFolderOperation operation,
        Gee.MultiMap<Geary.FolderPath, Geary.EmailIdentifier> folders_to_ids,
        Gee.Map<Geary.FolderPath, Geary.Folder> folders) throws Error {
        if (operation.restrict_to_folder != null) {
            if (folders_to_ids.contains(operation.restrict_to_folder))
                return operation.restrict_to_folder;
            return null;
        }
        
        bool best_is_open = false;
        int best_count = 0;
        Geary.FolderPath? best = null;
        foreach (Geary.FolderPath path in folders_to_ids.get_keys()) {
            assert(folders.has_key(path));
            if (!folders.get(path).get_type().is_a(operation.folder_type))
                continue;
            
            int count = folders_to_ids.get(path).size;
            if (count == 0)
                continue;
            
            // TODO: support REMOTE- or LOCAL-only here?
            if (folders.get(path).get_open_state() == Geary.Folder.OpenState.BOTH) {
                if (!best_is_open) {
                    best_is_open = true;
                    best_count = 0;
                }
            } else if (best_is_open) {
                continue;
            }
            
            if (count > best_count) {
                best_count = count;
                best = path;
            }
        }
        
        return best;
    }
    
    private async void do_folder_operation_async(AsyncFolderOperation operation,
        Gee.Collection<Geary.EmailIdentifier> emails, Cancellable? cancellable) throws Error {
        if (emails.size == 0)
            return;
        
        Gee.MultiMap<Geary.EmailIdentifier, Geary.FolderPath>? ids_to_folders
            = yield account.get_containing_folders_async(emails, cancellable);
        Gee.MultiMap<Geary.FolderPath, Geary.EmailIdentifier> folders_to_ids
            = Geary.Collection.reverse_multi_map<Geary.EmailIdentifier, Geary.FolderPath>(ids_to_folders);
        // TODO: don't build this up all at once, but only as they're needed.
        Gee.HashMap<Geary.FolderPath, Geary.Folder> folders
            = yield get_folder_instances_async(folders_to_ids.get_keys(), cancellable);
        
        Geary.FolderPath? path;
        while ((path = next_folder_for_operation(operation, folders_to_ids, folders)) != null) {
            Geary.Folder folder = folders.get(path);
            Gee.Collection<Geary.EmailIdentifier> ids = folders_to_ids.get(path);
            assert(ids.size > 0);
            
            bool open = false;
            try {
                // TODO: in cases of local-only ops, avoid doing a full open?
                yield folder.open_async(Geary.Folder.OpenFlags.NONE, cancellable);
                open = true;
                
                Gee.Collection<Geary.EmailIdentifier> used_ids
                    = yield operation.exec_async(folder, ids, cancellable);
                
                yield folder.close_async(cancellable);
                open = false;
                
                // We don't want to operate on any mails twice.
                foreach (Geary.EmailIdentifier id in used_ids.to_array()) {
                    foreach (Geary.FolderPath p in ids_to_folders.get(id))
                        folders_to_ids.remove(p, id);
                }
                // And we don't want to operate on the same folder twice.
                folders_to_ids.remove_all(path);
            } catch (Error e) {
                debug("Error performing an operation on messages in %s: %s", folder.to_string(), e.message);
                
                if (open) {
                    try {
                        yield folder.close_async(cancellable);
                        open = false;
                    } catch (Error e) {
                        debug("Error closing folder %s: %s", folder.to_string(), e.message);
                    }
                }
            }
        }
        
        if (folders_to_ids.size > 0)
            debug("Couldn't perform an operation on some messages in %s", account.to_string());
    }
}
