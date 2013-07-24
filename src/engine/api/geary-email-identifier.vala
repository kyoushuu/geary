/* Copyright 2011-2013 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

/**
 * A unique identifier for an {@link Email} throughout a Geary {@link Account}.
 *
 * Every Email has an {@link EmailIdentifier}.  Since the Geary engine supports the notion of an
 * Email being located in multiple {@link Folder}s, this identifier can be used to detect these
 * duplicates no matter how it's retrieved -- from any Folder or an Account object (i.e. via
 * search).
 *
 * EmailIdentifier is Comparable so it can be used as a sort stabilizer.
 *
 * The EmailIdentifier also represents the "natural" ordering for the Email it's associated with,
 * ''if the EmailIdentifier originated from a Folder''.  Otherwise, the ordering is unavailable.
 * Because of this, ordering is not used as a sort stabilizer in {@link compare_to}, but can be
 * used by callers if they need to sort identifiers (necessary when using
 * {@link Folder.list_email_by_id_async}.
 *
 * TODO: EmailIdentifiers may be expanded in the future to include Account information, meaning
 * they will be unique throughout the Geary engine.
 */

public abstract class Geary.EmailIdentifier : BaseObject, Gee.Hashable<Geary.EmailIdentifier>,
    Gee.Comparable<Geary.EmailIdentifier> {
    //public Gee.Comparable? ordering { get; private set; }
    
    private int64 value;
    
    // Although hidden from the user, uniqueness is established via a 64-bit value.  Since different
    // Email generators may use different storage or identification techniques, each subsystem
    // should implement a subclass.  This is used in equal_to() for testing.
    protected EmailIdentifier(int64 value, Gee.Comparable? ordering) {
        this.value = value;
        //this.ordering = ordering;
    }
    
    public virtual uint hash() {
        return Collection.int64_hash(value) ^ get_type().name().hash();
    }
    
    public virtual bool equal_to(Geary.EmailIdentifier other) {
        if (this == other)
            return true;
        
        // catch different subtypes
        if (get_type() != other.get_type())
            return false;
        
        return value == other.value;
    }
    
    public virtual int compare_to(Geary.EmailIdentifier other) {
        if (this == other)
            return 0;
        
        int cmp = strcmp(get_type().name(), other.get_type().name());
        if (cmp != 0)
            return cmp;
        
        return (int) (value - other.value).clamp(-1, 1);
    }
    
    public virtual string to_string() {
        return "[%s]".printf(value.to_string());
    }
}

