/* Copyright 2011-2013 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

// Draws the main toolbar.
public class MainToolbar : Gtk.Box {
    private const string ICON_CLEAR_NAME = "edit-clear-symbolic";
    private const string DEFAULT_SEARCH_TEXT = _("Search");
    
    private Gtk.Toolbar toolbar = new Gtk.Toolbar();
    public FolderMenu copy_folder_menu { get; private set; default = new FolderMenu(); }
    public FolderMenu move_folder_menu { get; private set; default = new FolderMenu(); }
    public string search_text { get { return search_entry.text; } }
    
    private Gtk.ToolItem search_container = new Gtk.ToolItem();
    private Gtk.Entry search_entry = new Gtk.Entry();
    private Geary.ProgressMonitor? search_upgrade_progress_monitor = null;
    private MonitoredProgressBar search_upgrade_progress_bar = new MonitoredProgressBar();
    
    public signal void search_text_changed(string search_text);
    
    public MainToolbar() {
        Object(orientation: Gtk.Orientation.VERTICAL, spacing: 0);
        GearyApplication.instance.controller.account_selected.connect(on_account_changed);
        
        // Assemble mark menu.
        GearyApplication.instance.load_ui_file("toolbar_mark_menu.ui");
        Gtk.Menu mark_menu = (Gtk.Menu) GearyApplication.instance.ui_manager.get_widget("/ui/ToolbarMarkMenu");
        mark_menu.foreach(GtkUtil.show_menuitem_accel_labels);
        
        // Setup the application menu.
        GearyApplication.instance.load_ui_file("toolbar_menu.ui");
        Gtk.Menu application_menu = (Gtk.Menu) GearyApplication.instance.ui_manager.get_widget("/ui/ToolbarMenu");
        application_menu.foreach(GtkUtil.show_menuitem_accel_labels);
        
        // Toolbar setup.
        toolbar.orientation = Gtk.Orientation.HORIZONTAL;
        toolbar.get_style_context().add_class(Gtk.STYLE_CLASS_MENUBAR); // Drag window via toolbar.
        Gee.List<Gtk.Button> insert = new Gee.ArrayList<Gtk.Button>();
        
        // Compose.
        insert.add(create_toolbar_button("text-editor-symbolic", GearyController.ACTION_NEW_MESSAGE));
        toolbar.add(create_pill_buttons(insert, false));
        
        // Reply buttons
        insert.clear();
        insert.add(create_toolbar_button("reply-symbolic", GearyController.ACTION_REPLY_TO_MESSAGE));
        insert.add(create_toolbar_button("reply-all-symbolic", GearyController.ACTION_REPLY_ALL_MESSAGE));
        insert.add(create_toolbar_button("forward-symbolic", GearyController.ACTION_FORWARD_MESSAGE));
        toolbar.add(create_pill_buttons(insert));
        
        // Mark, copy, move.
        insert.clear();
        insert.add(create_menu_button("marker-symbolic", mark_menu, GearyController.ACTION_MARK_AS_MENU));
        insert.add(create_menu_button("tag-symbolic", copy_folder_menu, GearyController.ACTION_COPY_MENU));
        insert.add(create_menu_button("move-symbolic", move_folder_menu, GearyController.ACTION_MOVE_MENU));
        toolbar.add(create_pill_buttons(insert));
        
        // Archive/delete button.
        // For this button, the controller sets the tooltip and icon depending on the context.
        insert.clear();
        insert.add(create_toolbar_button("", GearyController.ACTION_DELETE_MESSAGE));
        toolbar.add(create_pill_buttons(insert));
        
        // Spacer.
        Gtk.ToolItem spacer = new Gtk.ToolItem();
        spacer.set_expand(true);
        toolbar.add(spacer);
        
        // Search bar.
        search_entry.width_chars = 32;
        search_entry.primary_icon_name = "edit-find-symbolic";
        search_entry.secondary_icon_name = "edit-clear-symbolic";
        search_entry.secondary_icon_activatable = true;
        search_entry.secondary_icon_sensitive = true;
        search_entry.changed.connect(on_search_entry_changed);
        search_entry.icon_release.connect(on_search_entry_icon_release);
        search_entry.key_press_event.connect(on_search_key_press);
        on_search_entry_changed(); // set initial state
        search_entry.has_focus = true;
        search_container.add(search_entry);
        toolbar.add(search_container);
        
        // Application button.
        insert.clear();
        insert.add(create_menu_button("emblem-system-symbolic", application_menu, GearyController.ACTION_GEAR_MENU));
        toolbar.add(create_pill_buttons(insert));
        
        add(toolbar);
        set_search_placeholder_text(DEFAULT_SEARCH_TEXT);
    }
    
    public void set_search_text(string text) {
        search_entry.text = text;
    }
    
    public void set_search_placeholder_text(string placeholder) {
        search_entry.placeholder_text = placeholder;
    }
    
    private void on_search_entry_changed() {
        search_text_changed(search_entry.text);
        // Enable/disable clear button.
        search_entry.secondary_icon_name = search_entry.text != "" ? ICON_CLEAR_NAME : null;
    }
    
    private void on_search_entry_icon_release(Gtk.EntryIconPosition icon_pos, Gdk.Event event) {
        if (icon_pos == Gtk.EntryIconPosition.SECONDARY)
            search_entry.text = "";
    }
    
    private bool on_search_key_press(Gdk.EventKey event) {
        // Clear box if user hits escape.
        if (Gdk.keyval_name(event.keyval) == "Escape")
            search_entry.text = "";
        
        return false;
    }
    
    private void on_search_upgrade_start() {
        search_container.remove(search_container.get_child());
        search_container.add(search_upgrade_progress_bar);
        search_upgrade_progress_bar.show();
    }
    
    private void on_search_upgrade_finished() {
        search_container.remove(search_container.get_child());
        search_container.add(search_entry);
    }
    
    private void on_account_changed(Geary.Account? account) {
        on_search_upgrade_finished(); // Reset search box.
        
        if (search_upgrade_progress_monitor != null) {
            search_upgrade_progress_monitor.start.disconnect(on_search_upgrade_start);
            search_upgrade_progress_monitor.finish.disconnect(on_search_upgrade_finished);
            search_upgrade_progress_monitor = null;
        }
        
        if (account != null) {
            search_upgrade_progress_monitor = account.search_upgrade_monitor;
            search_upgrade_progress_bar.set_progress_monitor(search_upgrade_progress_monitor);
            
            search_upgrade_progress_monitor.start.connect(on_search_upgrade_start);
            search_upgrade_progress_monitor.finish.connect(on_search_upgrade_finished);
            if (search_upgrade_progress_monitor.is_in_progress)
                on_search_upgrade_start(); // Remove search box, we're already in progress.
        }
        
        search_upgrade_progress_bar.text = _("Indexing %s account").printf(account.information.nickname);
        
        set_search_placeholder_text(account == null || GearyApplication.instance.controller.get_num_accounts() == 1 ?
             DEFAULT_SEARCH_TEXT : _("Search %s account").printf(account.information.nickname));
    }
    
    private Gtk.Button create_toolbar_button(string icon_name, string action_name) {
        Gtk.Button b = new Gtk.Button();
        b.related_action = GearyApplication.instance.actions.get_action(action_name);
        b.tooltip_text = b.related_action.tooltip;
        b.image = new Gtk.Image.from_icon_name(icon_name, Gtk.IconSize.MENU);
        b.always_show_image = true;
        b.image.margin = get_icon_margin();
        
        if (!Geary.String.is_empty(b.related_action.label))
            b.image.margin_right += 4;
        
        return b;
    }
    
    private Gtk.MenuButton create_menu_button(string icon_name, Gtk.Menu? menu, string action_name) {
        Gtk.MenuButton b = new Gtk.MenuButton();
        b.related_action = GearyApplication.instance.actions.get_action(action_name); 
        b.tooltip_text = b.related_action.tooltip;
        b.image = new Gtk.Image.from_icon_name(icon_name, Gtk.IconSize.MENU);
        b.always_show_image = true;
        b.popup = menu;
        b.image.margin = get_icon_margin();
        
        if (!Geary.String.is_empty(b.related_action.label))
            b.image.margin_right += 4;
        
        return b;
    }
    
    // Given a list of buttons, creates a "pill-style" tool item that can be appended to a toolbar.
    private Gtk.ToolItem create_pill_buttons(Gee.Collection<Gtk.Button> buttons, bool left_spacer = true) {
        Gtk.Box box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        box.get_style_context().add_class(Gtk.STYLE_CLASS_RAISED);
        box.get_style_context().add_class(Gtk.STYLE_CLASS_LINKED);
        
        foreach(Gtk.Button button in buttons)
            box.add(button);
        
        Gtk.ToolItem tool_item = new Gtk.ToolItem();
        tool_item.add(box);
        
        if (left_spacer)
            box.set_margin_left(12);
        
        return tool_item;
    }
    
    // Computes the margin for each icon (shamelessly stolen from Nautilus.)
    private int get_icon_margin() {
        Gtk.IconSize toolbar_size = toolbar.get_icon_size();
        int toolbar_size_px, menu_size_px;
        
        Gtk.icon_size_lookup(Gtk.IconSize.MENU, out menu_size_px, null);
        Gtk.icon_size_lookup(toolbar_size, out toolbar_size_px, null);
        
        return Geary.Numeric.int_floor((int) ((toolbar_size_px - menu_size_px) / 2.0), 0);
    }
}

