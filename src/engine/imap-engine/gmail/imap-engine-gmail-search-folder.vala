/* Copyright 2013 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

/**
 * Gmail-specific SearchFolder implementation.
 */
public class Geary.ImapEngine.GmailSearchFolder : Geary.SearchFolder {
    private Geary.App.EmailStore email_store;
    private Geary.FolderPath? trash = null;
    
    public GmailSearchFolder(Geary.Account account) {
        base(account);
        
        email_store = new Geary.App.EmailStore(account);
        
        Geary.Folder? trash_folder = null;
        try {
            trash_folder = account.get_special_folder(Geary.SpecialFolderType.TRASH);
        } catch (Error e) {
            debug("Error looking up trash folder in %s: %s", account.to_string(), e.message);
        }
        
        if (trash_folder == null)
            debug("No trash folder found in %s", account.to_string());
        else
            trash = trash_folder.path;
    }
    
    public override async void remove_email_async(Gee.List<Geary.EmailIdentifier> email_ids,
        Cancellable? cancellable = null) throws Error {
        if (trash == null) {
            debug("Can't remove email from search folder because no trash folder was found in %s",
                account.to_string());
        } else {
            yield email_store.move_email_async(email_ids, trash, cancellable);
        }
    }
}
