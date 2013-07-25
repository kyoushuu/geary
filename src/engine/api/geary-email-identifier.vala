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
 * If the EmailIdentifier can represent a "natural" ordering for the Email (in particular, Email
 * that originates from a Folder), it should implement a Comparable interface.
 *
 * TODO: EmailIdentifiers may be expanded in the future to include Account information, meaning
 * they will be unique throughout the Geary engine.
 */

public abstract class Geary.EmailIdentifier : BaseObject, Gee.Hashable<Geary.EmailIdentifier> {
    private Collection.Unique unique;
    
    // Although hidden from the user, uniqueness is established via an Equalable value.  Since
    // different Email generators may use different storage or identification techniques, each subsystem
    // should implement a subclass.  This is used in equal_to() for testing.
    //
    // The unique_name is used for to_string(), but should truly be unique (i.e. derived from
    // unique, if not other values) so it can be used for stable_sort_comparator
    protected EmailIdentifier(Collection.Unique unique) {
        this.unique = unique;
    }
    
    public virtual uint hash() {
        return unique.hash() ^ get_type().name().hash();
    }
    
    public virtual bool equal_to(Geary.EmailIdentifier other) {
        if (this == other)
            return true;
        
        // catch different subtypes
        if (get_type() != other.get_type())
            return false;
        
        return unique.equal_to(other.unique);
    }
    
    /**
     * A comparator for stabilizing sorts.
     *
     * This has no bearing on a "natural" sort order for EmailIdentifiers and shouldn't be used
     * to indicate such.  This is why EmailIdentifier doesn't implement the Comparable interface.
     */
    public virtual int stable_sort_comparator(Geary.EmailIdentifier other) {
        if (this == other)
            return 0;
        
        int cmp = strcmp(get_type().name(), other.get_type().name());
        if (cmp != 0)
            return cmp;
        
        return unique.compare_to(other.unique);
    }
    
    public virtual string to_string() {
        return "[%s]".printf(unique.to_string());
    }
}

