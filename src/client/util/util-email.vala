/* Copyright 2011-2013 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

public int compare_conversation_ascending(Geary.App.Conversation a, Geary.App.Conversation b) {
    Gee.List<Geary.Email> apool = a.get_emails(Geary.App.Conversation.Ordering.DATE_ASCENDING);
    Gee.List<Geary.Email> bpool = b.get_emails(Geary.App.Conversation.Ordering.DATE_ASCENDING);
    
    if (apool.size == 0)
        return (bpool.size > 0) ? -1 : 0;
    else if (bpool.size == 0)
        return 1;
    
    return Geary.Email.compare_date_ascending(apool.last(), bpool.last());
}

public int compare_conversation_descending(Geary.App.Conversation a, Geary.App.Conversation b) {
    return compare_conversation_ascending(b, a);
}

