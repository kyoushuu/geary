/* Copyright 2011-2013 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

public class Geary.Imap.EmailFlags : Geary.EmailFlags {
    public MessageFlags message_flags { get; private set; }
    
    public EmailFlags(MessageFlags flags) {
        message_flags = flags;
        
        if (!flags.contains(MessageFlag.SEEN))
            add(UNREAD);
        
        if (flags.contains(MessageFlag.FLAGGED))
            add(FLAGGED);
        
        if (flags.contains(MessageFlag.LOAD_REMOTE_IMAGES))
            add(LOAD_REMOTE_IMAGES);
    }
    
    /**
     * Converts a generic {@link Geary.EmailFlags} to IMAP's internal representation of them.
     *
     * If the Geary.EmailFlags cannot be cast to IMAP's version, they're created.
     */
    public static Imap.EmailFlags from_api_email_flags(Geary.EmailFlags api_flags) {
        Imap.EmailFlags? imap_flags = api_flags as Imap.EmailFlags;
        if (imap_flags != null)
            return imap_flags;
        
        Gee.ArrayList<MessageFlag> msg_flags = new Gee.ArrayList<MessageFlag>();
        foreach (Geary.NamedFlag named_flag in api_flags.get_all())
            msg_flags.add(new MessageFlag(named_flag.name));
        
        return new Imap.EmailFlags(new MessageFlags(msg_flags));
    }
    
    protected override void notify_added(Gee.Collection<NamedFlag> added) {
        foreach (NamedFlag flag in added) {
            if (flag.equal_to(UNREAD))
                message_flags.remove(MessageFlag.SEEN);
            
            if (flag.equal_to(FLAGGED))
                message_flags.add(MessageFlag.FLAGGED);
            
            if (flag.equal_to(LOAD_REMOTE_IMAGES))
                message_flags.add(MessageFlag.LOAD_REMOTE_IMAGES);
        }
        
        base.notify_added(added);
    }
    
    protected override void notify_removed(Gee.Collection<NamedFlag> removed) {
        foreach (NamedFlag flag in removed) {
            if (flag.equal_to(UNREAD))
                message_flags.add(MessageFlag.SEEN);
            
            if (flag.equal_to(FLAGGED))
                message_flags.remove(MessageFlag.FLAGGED);
            
            if (flag.equal_to(LOAD_REMOTE_IMAGES))
                message_flags.remove(MessageFlag.LOAD_REMOTE_IMAGES);
        }
        
        base.notify_removed(removed);
    }
}

