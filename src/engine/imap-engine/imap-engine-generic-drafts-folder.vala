/* Copyright 2013 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

// Drafts folder supports most folder operations, but does not archive.
//
// Service-specific accounts can use this or subclass it for further customization

private class Geary.ImapEngine.GenericDraftsFolder : GenericFolder, Geary.FolderSupport.Remove,
    Geary.FolderSupport.Create {
    public GenericDraftsFolder(GenericAccount account, Imap.Account remote, ImapDB.Account local,
        ImapDB.Folder local_folder, SpecialFolderType special_folder_type) {
        base (account, remote, local, local_folder, special_folder_type);
    }
    
    public async void remove_email_async(Gee.List<Geary.EmailIdentifier> email_ids,
        Cancellable? cancellable = null) throws Error {
        yield expunge_email_async(email_ids, cancellable);
    }
    
    public new async Geary.EmailIdentifier? create_email_async(RFC822.Message message, Geary.EmailFlags? flags,
        DateTime? date_received, Geary.EmailIdentifier? id, Cancellable? cancellable) throws Error {
        return yield base.create_email_async(message, flags, date_received, id, cancellable);
    }
}

