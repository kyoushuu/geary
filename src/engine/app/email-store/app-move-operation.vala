/* Copyright 2013 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

private class Geary.App.MoveOperation : Geary.App.AsyncFolderOperation {
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
        yield move.move_email_async(list, destination, cancellable);
        return ids;
    }
}
