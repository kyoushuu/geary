/* Copyright 2011-2013 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

// Draws the main toolbar.
public class MainToolbar : Gtk.Box {
    private const string ICON_CLEAR_NAME = "edit-clear-symbolic";
    private const string DEFAULT_SEARCH_TEXT = _("Search");
    
    private Gtk.Toolbar toolbar;
    public FolderMenu copy_folder_menu { get; private set; }
    public FolderMenu move_folder_menu { get; private set; }
    public string search_text { get { return search_entry.text; } }
    
//    private GtkUtil.ToggleToolbarDropdown mark_menu_dropdown;
//    private GtkUtil.ToggleToolbarDropdown app_menu_dropdown;
    private Gtk.ToolItem search_container = new Gtk.ToolItem();
    private Gtk.Entry search_entry = new Gtk.Entry();
    private Geary.ProgressMonitor? search_upgrade_progress_monitor = null;
    private MonitoredProgressBar search_upgrade_progress_bar = new MonitoredProgressBar();
    
    public signal void search_text_changed(string search_text);
    
    public MainToolbar() {
        Object(orientation: Gtk.Orientation.HORIZONTAL, spacing: 0);
        
        GearyApplication.instance.controller.account_selected.connect(on_account_changed);
        
        //Gtk.Builder builder = GearyApplication.instance.create_builder("toolbar.glade");
        //toolbar = builder.get_object("toolbar") as Gtk.Toolbar;
        
        // Setup the folder menus.
        copy_folder_menu = new FolderMenu(
            IconFactory.instance.get_custom_icon("tag-new", IconFactory.ICON_TOOLBAR),
            Gtk.IconSize.LARGE_TOOLBAR, null, null);
//        copy_folder_menu.attach(copy_button);
//        
        move_folder_menu = new FolderMenu(
            IconFactory.instance.get_custom_icon("mail-move", IconFactory.ICON_TOOLBAR),
            Gtk.IconSize.LARGE_TOOLBAR, null, null);
//        move_folder_menu.attach(move_button);
        
        // Assemble mark menu button.
        GearyApplication.instance.load_ui_file("toolbar_mark_menu.ui");
        Gtk.Menu mark_menu = (Gtk.Menu) GearyApplication.instance.ui_manager.get_widget("/ui/ToolbarMarkMenu");
                
        // Ensure that shortcut keys are drawn in the mark menu
        //mark_menu.foreach(GtkUtil.show_menuitem_accel_labels);
        
      /*  Gtk.Menu mark_proxy_menu = (Gtk.Menu) GearyApplication.instance.ui_manager
            .get_widget("/ui/ToolbarMarkMenuProxy");
        mark_menu_dropdown = new GtkUtil.ToggleToolbarDropdown(
            IconFactory.instance.get_custom_icon("edit-mark", IconFactory.ICON_TOOLBAR),
            Gtk.IconSize.LARGE_TOOLBAR, mark_menu, mark_proxy_menu); */
        
        toolbar = new Gtk.Toolbar();
        toolbar.orientation = Gtk.Orientation.HORIZONTAL;
        
        Gee.List<Gtk.Button> insert = new Gee.ArrayList<Gtk.Button>();
        
        // Compose.
        insert.add(create_toolbar_button("mail-unread-symbolic", GearyController.ACTION_NEW_MESSAGE));
        toolbar.add(create_pill_buttons(insert, false));
        
        // Reply buttons
        insert.clear();
        insert.add(create_toolbar_button("mail-reply-sender", GearyController.ACTION_REPLY_TO_MESSAGE));
        insert.add(create_toolbar_button("mail-reply-all", GearyController.ACTION_REPLY_ALL_MESSAGE));
        insert.add(create_toolbar_button("mail-forward", GearyController.ACTION_FORWARD_MESSAGE));
        toolbar.add(create_pill_buttons(insert));
        
        // Mark, copy, move.
        insert.clear();
        insert.add(create_menu_button("edit-mark", mark_menu, GearyController.ACTION_MARK_AS_MENU));
        insert.add(create_menu_button("tag-new", null, GearyController.ACTION_COPY_MENU));
        insert.add(create_menu_button("mail-move", null, GearyController.ACTION_MOVE_MENU));
        toolbar.add(create_pill_buttons(insert));
        
        // Archive/delete button.
        // For this button, the controller sets the tooltip and icon depending on the context.
        insert.clear();
        insert.add(create_toolbar_button("", GearyController.ACTION_DELETE_MESSAGE));
        toolbar.add(create_pill_buttons(insert));
        
        // Spacer.
        Gtk.ToolItem spacer = new Gtk.ToolItem();
    //    spacer.hexpand = true;
        spacer.expand = true;
        spacer.set_homogeneous(false);
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
       
       /* 
        // Setup the application menu.
        GearyApplication.instance.load_ui_file("toolbar_menu.ui");
        Gtk.Menu application_menu = GearyApplication.instance.ui_manager.get_widget("/ui/ToolbarMenu")
            as Gtk.Menu;
        
        // Ensure that shortcut keys are drawn in the gear menu
        application_menu.foreach(GtkUtil.show_menuitem_accel_labels);
        
        Gtk.Menu application_proxy_menu = GearyApplication.instance.ui_manager.get_widget("/ui/ToolbarMenuProxy")
            as Gtk.Menu;
        Gtk.ToggleToolButton app_menu_button = set_toolbutton_action(builder, GearyController.ACTION_GEAR_MENU)
            as Gtk.ToggleToolButton;
        app_menu_dropdown = new GtkUtil.ToggleToolbarDropdown(
            IconFactory.instance.get_theme_icon("application-menu"), Gtk.IconSize.LARGE_TOOLBAR,
            application_menu, application_proxy_menu);
        app_menu_dropdown.show_arrow = false;
        app_menu_dropdown.attach(app_menu_button);
        
        */
        
       // toolbar.get_style_context().add_class("primary-toolbar");
        
//        search_upgrade_progress_bar.show_text = true;
//        search_upgrade_progress_bar.margin_top = search_upgrade_progress_bar.margin_bottom = 3;
        
        // Let users drag window with the toolbar.
        toolbar.get_style_context().add_class(Gtk.STYLE_CLASS_MENUBAR);
        
        add(toolbar);
        set_search_placeholder_text(DEFAULT_SEARCH_TEXT);
    }
    
//    private Gtk.ToolButton set_toolbutton_action(Gtk.Builder builder, string action,
//        bool use_action_appearance = false) {
//        Gtk.ToolButton button = builder.get_object(action) as Gtk.ToolButton;
//        
//        // Must manually set use_action_appearance to false until Glade re-adds this feature.
//        // See this ticket: https://bugzilla.gnome.org/show_bug.cgi?id=694407#c11
//        button.use_action_appearance = use_action_appearance;
//        button.set_related_action(GearyApplication.instance.actions.get_action(action));
//        return button;
//    }
    
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
        b.image = new Gtk.Image.from_icon_name(icon_name, Gtk.IconSize.LARGE_TOOLBAR);
        b.image.margin_right = 4;
        b.always_show_image = true;
        
        return b;
    }
    
    private Gtk.MenuButton create_menu_button(string icon_name, Gtk.Menu? menu, string action_name) {
        Gtk.MenuButton b = new Gtk.MenuButton();
        b.related_action = GearyApplication.instance.actions.get_action(action_name); 
        b.image = new Gtk.Image.from_icon_name(icon_name, Gtk.IconSize.LARGE_TOOLBAR);
        b.image.margin_right = 4;
        b.always_show_image = true;
        b.popup = menu;
        
        return b;
    }
    
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
}

