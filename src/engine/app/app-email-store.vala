/* Copyright 2013 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

public class Geary.App.EmailStore : BaseObject {
    // TODO: move these out into separate files.
    private abstract class AsyncFolderOperation : BaseObject {
        public abstract async Gee.Collection<Geary.EmailIdentifier> exec_async(
            Geary.Folder folder, Gee.Collection<Geary.EmailIdentifier> ids,
            Cancellable? cancellable) throws Error;
    }
    
    private class ListOperation : AsyncFolderOperation {
        public static Type folder_type = typeof(Geary.Folder);
        
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
    
    private class MarkOperation : AsyncFolderOperation {
        public static Type folder_type = typeof(Geary.FolderSupport.Mark);
        
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
    
    public Geary.Account account { get; private set; }
    
    public EmailStore(Geary.Account account) {
        this.account = account;
    }
    
    // TODO: fetch op (that just uses ListOperation internally?)
    
    /**
     * Lists any set of EmailIdentifiers as if they were all in one folder.
     */
    public async Gee.Collection<Geary.Email>? list_email_by_sparse_id_async(
        Gee.Collection<Geary.EmailIdentifier> emails, Geary.Email.Field required_fields,
        Geary.Folder.ListFlags flags, Cancellable? cancellable = null) throws Error {
        ListOperation op = new ListOperation(required_fields, flags);
        yield do_folder_operation_async(op, ListOperation.folder_type, emails, cancellable);
        return (op.results.size > 0 ? op.results : null);
    }
    
    /**
     * Marks any set of EmailIdentifiers as if they were all in one
     * Geary.FolderSupport.Mark folder.
     */
    public async void mark_email_async(Gee.Collection<Geary.EmailIdentifier> emails,
        Geary.EmailFlags? flags_to_add, Geary.EmailFlags? flags_to_remove,
        Cancellable? cancellable = null) throws Error {
        yield do_folder_operation_async(new MarkOperation(flags_to_add, flags_to_remove),
            MarkOperation.folder_type, emails, cancellable);
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
    
    private Geary.FolderPath? next_folder_for_operation(Type folder_type,
        Gee.MultiMap<Geary.FolderPath, Geary.EmailIdentifier> folders_to_ids,
        Gee.Map<Geary.FolderPath, Geary.Folder> folders) throws Error {
        bool best_is_open = false;
        int best_count = 0;
        Geary.FolderPath? best = null;
        // TODO: prefer currently open folders first?
        foreach (Geary.FolderPath path in folders_to_ids.get_keys()) {
            assert(folders.has_key(path));
            if (!folders.get(path).get_type().is_a(folder_type))
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
            
            int count = folders_to_ids.get(path).size;
            if (count > best_count) {
                best_count = count;
                best = path;
            }
        }
        
        return best;
    }
    
    private async void do_folder_operation_async(AsyncFolderOperation operation, Type folder_type,
        Gee.Collection<Geary.EmailIdentifier> emails, Cancellable? cancellable) throws Error {
        if (emails.size == 0)
            return;
        
        Gee.MultiMap<Geary.EmailIdentifier, Geary.FolderPath>? ids_to_folders
            = yield account.get_containing_folders_async(emails, cancellable);
        Gee.MultiMap<Geary.FolderPath, Geary.EmailIdentifier> folders_to_ids
            = Geary.Collection.reverse_multi_map<Geary.EmailIdentifier, Geary.FolderPath>(ids_to_folders);
        Gee.HashMap<Geary.FolderPath, Geary.Folder> folders
            = yield get_folder_instances_async(folders_to_ids.get_keys(), cancellable);
        
        Geary.FolderPath? path;
        while ((path = next_folder_for_operation(folder_type, folders_to_ids, folders)) != null) {
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
            } catch (Error e) {
                debug("Error performing an operation on messages in %s: %s", account.to_string(), e.message);
                
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
