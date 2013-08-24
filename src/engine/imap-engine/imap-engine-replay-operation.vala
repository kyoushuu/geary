/* Copyright 2012-2013 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

private abstract class Geary.ImapEngine.ReplayOperation : Geary.BaseObject {
    /**
     * Scope specifies what type of operations (remote, local, or both) are needed by this operation.
     * What methods are made on the operation depends on the returned Scope:
     *
     * LOCAL_AND_REMOTE: replay_local_async() is called.  If that method returns COMPLETED,
     *   no further calls are made.  If it returns CONTINUE, replay_remote_async() is called.
     *   query_local_writebehind_operation() may be called before replay_remote_async().
     * LOCAL_ONLY: replay_local_async() only.  replay_remote_async() will never be called.
     *   query_local_writebehind_operation() will never be called.
     * REMOTE_ONLY: replay_remote_async() only.  replay_local_async() will never be called.
     *   query_local_writebehind_operation() may be called before replay_remote_async().
     *
     * See the various replay methods for how backout_local_async() may be called depending on
     * this field and those methods' return values.
     */
    public enum Scope {
        LOCAL_AND_REMOTE,
        LOCAL_ONLY,
        REMOTE_ONLY
    }
    
    public enum Status {
        COMPLETED,
        FAILED,
        CONTINUE
    }
    
    private static int next_opnum = 0;
    
    public string name { get; set; }
    public int opnum { get; private set; }
    public Scope scope { get; private set; }
    public Error? err { get; private set; default = null; }
    public bool failed { get; private set; default = false; }
    public bool notified { get; private set; default = false; }
    
    private Nonblocking.Semaphore semaphore = new Nonblocking.Semaphore();
    
    public ReplayOperation(string name, Scope scope) {
        this.name = name;
        opnum = next_opnum++;
        this.scope = scope;
    }
    
    /**
     * See Scope for conditions where this method will be called.
     *
     * Returns:
     *   COMPLETED: the operation has completed and no further calls should be made.
     *   FAILED: the operation has failed.  (An exception may be thrown for similar effect.)
     *     backout_local_async() will *not* be executed.
     *   CONTINUE: The local operation has completed and the remote portion must be executed as
     *      well.  This is treated as COMPLETED if get_scope() returns LOCAL_ONLY.
     */
    public abstract async Status replay_local_async() throws Error;
    
    /**
     * See Scope for conditions where this method will be called.
     *
     * This method is called only when the ReplayOperation is blocked waiting to execute a remote
     * command and its discovered that the supplied email(s) are no longer on the server.
     * This happens during folder normalization (initial synchronization with the server
     * when a folder is opened) where ReplayOperations are allowed to execute locally and enqueue
     * for remote operation in preparation for the folder to fully open.
     *
     * The ReplayOperation should remove any reference to the emails so not to attempt operation
     * on the server.  If it's discovered in replay_remote_async() that there are no more operations
     * to perform, it should simply exit without contacting the server.
     */
    public abstract void notify_remote_removed_during_normalization(Gee.Collection<ImapDB.EmailIdentifier> ids);
    
    /**
     * See Scope for conditions where this method will be called.
     *
     * Returns:
     *   COMPLETED: the operation has completed and no further calls should be made.
     *   FAILED: the operation has failed.  (An exception may be thrown for similar effect.)
     *     backout_local_async() will be executed only if scope is LOCAL_AND_REMOTE.
     *   CONTINUE: Treated as COMPLETED.
     */
    public abstract async Status replay_remote_async() throws Error;
    
    /**
     * See Scope, replay_local_async(), and replay_remote_async() for conditions for this where this
     * will be called.
     */
    public abstract async void backout_local_async() throws Error;
    
    /**
     * Completes when the operation has completed execution.  If the operation threw an error
     * during execution, it will be thrown here.  If the operation failed, this returns false.
     */
    public async bool wait_for_ready_async(Cancellable? cancellable = null) throws Error {
        yield semaphore.wait_async(cancellable);
        
        if (err != null)
            throw err;
        
        return failed;
    }
    
    internal void notify_ready(bool failed, Error? err) {
        assert(!notified);
        
        notified = true;
        
        this.failed = failed;
        this.err = err;
        
        try {
            semaphore.notify();
        } catch (Error notify_err) {
            debug("Unable to notify replay operation as ready: [%s] %s", name, notify_err.message);
        }
    }
    
    public abstract string describe_state();
    
    public string to_string() {
        string state = describe_state();
        
        return (String.is_empty(state)) ? "[%d] %s".printf(opnum, name)
            : "[%d] %s: %s".printf(opnum, name, state);
    }
}

