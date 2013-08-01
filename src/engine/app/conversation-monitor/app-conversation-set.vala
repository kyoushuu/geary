/* Copyright 2013 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

private class Geary.App.ConversationSet : BaseObject {
    private Gee.Set<Conversation> _conversations = new Gee.HashSet<Conversation>();
    
    // Maps email ids to conversations.
    private Gee.HashMap<Geary.EmailIdentifier, Conversation> email_id_map
        = new Gee.HashMap<Geary.EmailIdentifier, Conversation>();
    
    // Only contains the Message-ID headers of emails actually in
    // conversations.
    private Gee.HashMap<Geary.RFC822.MessageID, Conversation> contained_message_id_map
        = new Gee.HashMap<Geary.RFC822.MessageID, Conversation>();
    
    // Contains the full set of Message IDs theoretically in each conversation,
    // as determined by the ancestors of all messages in the conversation.
    private Gee.HashMap<Geary.RFC822.MessageID, Conversation> logical_message_id_map
        = new Gee.HashMap<Geary.RFC822.MessageID, Conversation>();
    
    public int size { get { return _conversations.size; } }
    public bool is_empty { get { return _conversations.is_empty; } }
    public Gee.Collection<Conversation> conversations {
        owned get { return _conversations.read_only_view; }
    }
    
    public ConversationSet() {
    }
    
    public int get_email_count() {
        return email_id_map.size;
    }
    
    public bool contains(Conversation conversation) {
        return _conversations.contains(conversation);
    }
    
    public bool has_email_identifier(Geary.EmailIdentifier id) {
        return email_id_map.has_key(id);
    }
    
    /**
     * Return whether the set has the given Message ID.  If logical_set,
     * there's no requirement that any conversation actually contain a message
     * with a matching Message-ID header, and any Message ID matching any
     * ancestor of any message in any conversation will match.
     */
    public bool has_message_id(Geary.RFC822.MessageID message_id, bool logical_set = false) {
        return (logical_set ? logical_message_id_map : contained_message_id_map).has_key(message_id);
    }
    
    public Conversation? get_by_email_identifier(Geary.EmailIdentifier id) {
        return email_id_map.get(id);
    }
    
    /**
     * Return the conversation the given Message ID belongs to.  If
     * logical_set, the Message ID may match any ancestor of any message in any
     * conversation; else it must match the Message-ID header of an email in
     * any conversation.  Return null if not found.
     */
    public Conversation? get_by_message_id(Geary.RFC822.MessageID message_id,
        bool logical_set = false) {
        return (logical_set ? logical_message_id_map : contained_message_id_map).get(message_id);
    }
    
    public void clear_owners() {
        foreach (Conversation conversation in _conversations)
            conversation.clear_owner();
    }
    
    private void remove_email_from_conversation(Conversation conversation, Geary.Email email) {
        // Be very strict about our internal state getting out of whack, since
        // it would indicate a nasty error in our logic that we need to fix.
        if (!email_id_map.unset(email.id))
            error("Email %s already removed from conversation set", email.id.to_string());
        
        if (email.message_id != null) {
            if (!contained_message_id_map.unset(email.message_id))
                error("Message-ID %s already removed from conversation set", email.message_id.to_string());
        }
        
        Gee.Set<Geary.RFC822.MessageID>? removed_message_ids = conversation.remove(email);
        if (removed_message_ids != null) {
            foreach (Geary.RFC822.MessageID removed_message_id in removed_message_ids) {
                if (!logical_message_id_map.unset(removed_message_id)) {
                    error("Message ID %s already removed from conversation set logical map",
                        removed_message_id.to_string());
                }
            }
        }
    }
    
    /**
     * Add the email (requires Field.REFERENCES) to the mix, potentially
     * replacing an existing email with the same id, or creating a new
     * conversation if necessary.  In the event of a duplicate (as detected by
     * Message-ID), the email whose EmailIdentifier has the
     * preferred_folder_path will be kept, and the other discarded (note that
     * we always prefer an identifier with a non-null folder path over a null
     * folder path, regardless of what the non-null path is).  Return null if
     * we didn't add the email (e.g. it was a dupe and we preferred the
     * existing email), or the conversation it was added to.  Return in
     * added_conversation whether a new conversation was created.
     */
    public Conversation? add_email(Geary.Email email, ConversationMonitor monitor,
        Geary.FolderPath? preferred_folder_path, out bool added_conversation) {
        added_conversation = false;
        
        if (email_id_map.has_key(email.id))
            return null;
        
        Gee.Set<Geary.RFC822.MessageID>? ancestors = email.get_ancestors();
        
        Conversation? conversation = null;
        if (ancestors != null) {
            foreach (Geary.RFC822.MessageID ancestor in ancestors) {
                conversation = logical_message_id_map.get(ancestor);
                if (conversation != null)
                    break;
            }
        }
        
        if (conversation == null) {
            conversation = new Conversation(monitor);
            _conversations.add(conversation);
            
            added_conversation = true;
        }
        
        if (!conversation.add(email)) {
            error("Couldn't add duplicate email %s to conversation %s",
                email.id.to_string(), conversation.to_string());
        }
        
        email_id_map.set(email.id, conversation);
        
        if (email.message_id != null)
            contained_message_id_map.set(email.message_id, conversation);
        
        if (ancestors != null) {
            foreach (Geary.RFC822.MessageID ancestor in ancestors)
                logical_message_id_map.set(ancestor, conversation);
        }
        
        return conversation;
    }
    
    public void add_all_emails(Gee.Collection<Geary.Email> emails,
        ConversationMonitor monitor, Geary.FolderPath? preferred_folder_path,
        out Gee.Collection<Conversation> added,
        out Gee.MultiMap<Conversation, Geary.Email> appended) {
        Gee.HashSet<Conversation> _added = new Gee.HashSet<Conversation>();
        Gee.HashMultiMap<Conversation, Geary.Email> _appended
            = new Gee.HashMultiMap<Conversation, Geary.Email>();
        
        foreach (Geary.Email email in emails) {
            bool added_conversation;
            Conversation? conversation = add_email(
                email, monitor, preferred_folder_path, out added_conversation);
            
            if (conversation == null)
                continue;
            
            if (added_conversation) {
                _added.add(conversation);
            } else {
                if (!_added.contains(conversation))
                    _appended.set(conversation, email);
            }
        }
        
        added = _added;
        appended = _appended;
    }
    
    public Conversation? remove_email_by_identifier(Geary.EmailIdentifier id,
        out Geary.Email? removed_email, out bool removed_conversation) {
        removed_email = null;
        removed_conversation = false;
        
        Conversation? conversation = email_id_map.get(id);
        if (conversation == null) {
            debug("Removed email %s not found in conversation set", id.to_string());
            return null;
        }
        
        Geary.Email? email = conversation.get_email_by_id(id);
        if (email == null)
            error("Unable to locate email %s in conversation %s", id.to_string(), conversation.to_string());
        removed_email = email;
        
        remove_email_from_conversation(conversation, email);
        
        // Evaporate conversations with no more messages in the folder.
        // TODO: Need to determine this properly
        if (conversation.get_count_in_folder() == 0) {
            foreach (Geary.Email conversation_email in conversation.get_emails(Conversation.Ordering.NONE))
                remove_email_from_conversation(conversation, conversation_email);
            
            if (!_conversations.remove(conversation))
                error("Conversation %s already removed from set", conversation.to_string());
            debug("Removing email %s evaporates conversation %s", id.to_string(), conversation.to_string());
            
            conversation.clear_owner();
            
            removed_conversation = true;
        }
        
        return conversation;
    }
    
    public void remove_all_emails_by_identifier(Gee.Collection<Geary.EmailIdentifier> ids,
        out Gee.Collection<Conversation> removed,
        out Gee.MultiMap<Conversation, Geary.Email> trimmed) {
        Gee.HashSet<Conversation> _removed = new Gee.HashSet<Conversation>();
        Gee.HashMultiMap<Conversation, Geary.Email> _trimmed
            = new Gee.HashMultiMap<Conversation, Geary.Email>();
        
        foreach (Geary.EmailIdentifier id in ids) {
            Geary.Email email;
            bool removed_conversation;
            Conversation? conversation = remove_email_by_identifier(
                id, out email, out removed_conversation);
            
            if (conversation == null)
                continue;
            
            if (removed_conversation) {
                if (_trimmed.contains(conversation))
                    _trimmed.remove_all(conversation);
                _removed.add(conversation);
            } else {
                _trimmed.set(conversation, email);
            }
        }
        
        removed = _removed;
        trimmed = _trimmed;
    }
}
