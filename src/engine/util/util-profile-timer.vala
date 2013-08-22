public class Geary.Util.ProfileTimer : BaseObject {
    public static string log_filename = "./geary.profile";
    public static FileOutputStream? log_file = null;
    private static int next_id = 0;
    
    private Timer t;
    private int id;
    private string name;
    
    public ProfileTimer(string name) {
        t = new Timer();
        t.start();
        id = next_id++;
        this.name = name;
        
        note("started");
    }
    
    ~ProfileTimer() {
        note_elapsed("finished");
    }
    
    public void note(string message) {
        log("%04d:%s %s\n".printf(id, name, message));
    }
    
    public void note_elapsed(string message) {
        ulong s, us;
        s = (ulong) t.elapsed(out us);
        
        log("%04d:%s %s at %lu.%06lus\n".printf(id, name, message, s, us));
    }
    
    private static void log(string message) {
        if (log_file == null) {
            try {
                log_file = File.new_for_path(log_filename).append_to(FileCreateFlags.NONE);
                log_file.write("=== %s ===\n".printf(new DateTime.now_local().to_string()).data);
            } catch (Error e) {
                debug("Error creating profile log: %s", e.message);
                return;
            }
        }
        
        try {
            log_file.write(message.data);
        } catch (Error e) {
            debug("Error writing to profile log: %s", e.message);
        }
    }
}
