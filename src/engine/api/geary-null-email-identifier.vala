/* Copyright 2013 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

/**
 * A temporary {@link EmailIdentifier} used when an {@link Email}'s unique one has not yet been
 * generated.
 *
 * A {@link NullEmailIdentifier} is not equal with any other EmailIdentifier save its own instance.
 */

private class Geary.NullEmailIdentifier : EmailIdentifier {
    private static int64 next_value = 0;
    
    public NullEmailIdentifier() {
        int64 value;
        lock (next_value) {
            value = next_value++;
        }
        
        base (value);
    }
}

