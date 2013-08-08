/* Copyright 2013 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

private abstract class Geary.App.AsyncFolderOperation : BaseObject {
    public abstract Type folder_type { get; }
    public virtual Geary.FolderPath? restrict_to_folder { get { return null; } }
    
    public abstract async Gee.Collection<Geary.EmailIdentifier> execute_async(
        Geary.Folder folder, Gee.Collection<Geary.EmailIdentifier> ids,
        Cancellable? cancellable) throws Error;
}
