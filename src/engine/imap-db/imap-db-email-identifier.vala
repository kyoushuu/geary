/* Copyright 2011-2013 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

private class Geary.ImapDB.EmailIdentifier : Geary.EmailIdentifier {
    public Imap.UID? uid { get; private set; }
    
    public EmailIdentifier(int64 message_id, Imap.UID? uid) {
        base (message_id, uid);
        
        this.uid = uid;
    }
}
