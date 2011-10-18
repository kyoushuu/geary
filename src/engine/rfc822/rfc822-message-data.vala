/* Copyright 2011 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution. 
 */

/**
 * RFC822.MessageData represents a base class for all the various elements that may be present in
 * an RFC822 message header.  Note that some common elements (such as MailAccount) are not
 * MessageData because they exist in an RFC822 header in list (i.e. multiple email addresses) form.
 */

public interface Geary.RFC822.MessageData : Geary.Common.MessageData {
}

public class Geary.RFC822.MessageID : Geary.Common.StringMessageData, Geary.RFC822.MessageData,
    Geary.Equalable {
    public MessageID(string value) {
        base (value);
    }
    
    public bool equals(Equalable e) {
        MessageID? message_id = e as MessageID;
        if (message_id == null)
            return false;
        
        if (this == message_id)
            return true;
        
        return value == message_id.value;
    }
}

public class Geary.RFC822.MessageIDList : Geary.Common.StringMessageData, Geary.RFC822.MessageData {
    private Gee.List<MessageID>? list = null;
    
    public MessageIDList(string value) {
        base (value);
    }
    
    public Gee.List<MessageID> decoded() {
        if (list != null)
            return list;
        
        list = new Gee.ArrayList<MessageID>(Equalable.equal_func);
        
        string[] ids = value.split(" ");
        foreach (string id in ids) {
            id = id.strip();
            if (!String.is_empty(id))
                list.add(new MessageID(id));
        }
        
        return list;
    }
}

public class Geary.RFC822.Date : Geary.RFC822.MessageData, Geary.Common.MessageData {
    public string original { get; private set; }
    public DateTime value { get; private set; }
    public time_t as_time_t { get; private set; }
    
    public Date(string iso8601) throws ImapError {
        as_time_t = GMime.utils_header_decode_date(iso8601, null);
        if (as_time_t == 0)
            throw new ImapError.PARSE_ERROR("Unable to parse \"%s\": not ISO-8601 date", iso8601);
        
        value = new DateTime.from_unix_local(as_time_t);
        original = iso8601;
    }
    
    public override string to_string() {
        return original;
    }
}

public class Geary.RFC822.Size : Geary.Common.LongMessageData, Geary.RFC822.MessageData {
    public Size(long value) {
        base (value);
    }
}

public class Geary.RFC822.Subject : Geary.Common.StringMessageData, Geary.RFC822.MessageData {
    public Subject(string value) {
        base (value);
    }
    
    public Subject.from_rfc822(string value) {
        base (GMime.utils_header_decode_text(value));
    }
}

public class Geary.RFC822.Header : Geary.Common.BlockMessageData, Geary.RFC822.MessageData {
    private GMime.Message? message = null;
    private string[]? names = null;
    
    public Header(Geary.Memory.AbstractBuffer buffer) {
        base ("RFC822.Header", buffer);
    }
    
    private unowned GMime.HeaderList get_headers() throws RFC822Error {
        if (message != null)
            return message.get_header_list();
        
        GMime.Parser parser = new GMime.Parser.with_stream(
            new GMime.StreamMem.with_buffer(buffer.get_array()));
        parser.set_respect_content_length(false);
        parser.set_scan_from(false);
        
        message = parser.construct_message();
        if (message == null)
            throw new RFC822Error.INVALID("Unable to parse RFC 822 headers");
        
        return message.get_header_list();
    }
    
    public string get_header(string name) throws RFC822Error {
        return get_headers().get(name);
    }
    
    public string[] get_header_names() throws RFC822Error {
        if (names != null)
            return names;
        
        names = new string[0];
        
        unowned GMime.HeaderIter iter;
        if (!get_headers().get_iter(out iter))
            return names;
        
        do {
            names += iter.get_name();
        } while (iter.next());
        
        return names;
    }
}

public class Geary.RFC822.Text : Geary.Common.BlockMessageData, Geary.RFC822.MessageData {
    public Text(Geary.Memory.AbstractBuffer buffer) {
        base ("RFC822.Text", buffer);
    }
}

public class Geary.RFC822.Full : Geary.Common.BlockMessageData, Geary.RFC822.MessageData {
    public Full(Geary.Memory.AbstractBuffer buffer) {
        base ("RFC822.Full", buffer);
    }
}
