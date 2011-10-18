/* Copyright 2011 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution. 
 */

/**
 * An EmailLocation represents an Email's position (cardinal ordering) in a Folder.  Unlike other
 * elements in an Email, it may change over time, depending on events within the Folder itself.
 * It reports these changes via signals.
 *
 * An EmailLocation's position is a cardinal (1 to n) of an Email's ordering within the Folder.
 * Its ordering is an opaque number that was used to determine this ordering -- it may be exactly
 * equal to its position, or it may not.  This value is particular to the message provider and
 * should not be depended on.
 *
 * When the Folder closes, the EmailLocation will fire its "invalidated" signal and go into an
 * invalidated state.  Its position will be -1.  The EmailLocation will never go back to a valid
 * state; the owner should discard the EmailLocation (and, by extension, its Email) after the Folder
 * has closed and fetch fresh ones once its re-opened.
 *
 * Note the differences between an EmailLocation, which gives a cardinal way of addressing mail in
 * a folder, an an EmailIdentifier, which is unique and immutable, but is only addressable as a
 * singleton, and not by a range.
 */
public class Geary.EmailLocation : Object {
    /**
     * Returns -1 if invalidated.
     */
    public int position { get; private set; }
    public int64 ordering { get; private set; }
    
    private Geary.Folder folder;
    
    public signal void position_altered(int old_position, int new_position);
    
    public signal void position_deleted(int position);
    
    /**
     * "invalidated" is fired when the EmailLocation object is no longer valid due to the Folder
     * closing.  At this point, its position will be -1.
     */
    public signal void invalidated();
    
    public EmailLocation(Geary.Folder folder, int position, int64 ordering) {
        assert(position >= 1);
        
        this.folder = folder;
        this.position = position;
        this.ordering = ordering;
        
        folder.message_removed.connect(on_message_removed);
        folder.closed.connect(on_folder_closed);
    }
    
    ~EmailLocation() {
        invalidate(false);
    }
    
    private void invalidate(bool signalled) {
        if (position < 0)
            return;
        
        position = -1;
        
        folder.message_removed.disconnect(on_message_removed);
        folder.closed.disconnect(on_folder_closed);
        
        if (signalled)
            invalidated();
    }
    
    private void on_message_removed(int position, int total) {
        // bail out if invalidated
        if (position < 1)
            return;
        
        // if the removed position is greater than this one's, no change in this position
        if (this.position < position)
            return;
        
        // if the same, can't adjust (adjust it to what?), but notify that this EmailLocation has
        // been removed
        if (this.position == position) {
            position_deleted(position);
            
            return;
        }
        
        // adjust this position downward
        int old_position = this.position;
        this.position--;
        assert(this.position >= 1);
        
        position_altered(old_position, this.position);
    }
    
    private void on_folder_closed() {
        invalidate(true);
    }
}
