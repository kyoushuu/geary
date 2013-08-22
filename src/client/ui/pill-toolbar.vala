/* Copyright 2011-2013 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

/**
 * Class for creating a Nautilus-style "pill" toolbar.  Use only as directed.
 */
public class PillToolbar : Gtk.Toolbar {
    private Gtk.ActionGroup action_group;
    
    public PillToolbar(Gtk.ActionGroup toolbar_action_group) {
        action_group = toolbar_action_group;
    }
    
    private void setup_button(Gtk.Button b, string? icon_name, string action_name) {
        b.related_action = action_group.get_action(action_name);
        b.tooltip_text = b.related_action.tooltip;
        b.image = new Gtk.Image.from_icon_name(icon_name != null ? icon_name :
            b.related_action.icon_name, Gtk.IconSize.MENU);
        b.always_show_image = true;
        b.image.margin = get_icon_margin();
        
        if (!Geary.String.is_empty(b.related_action.label))
            b.image.margin_right += 4;
    }
    
    /**
     * Given an icon and action, creates a button that triggers the action.
     */
    public Gtk.Button create_toolbar_button(string? icon_name, string action_name) {
        Gtk.Button b = new Gtk.Button();
        setup_button(b, icon_name, action_name);
        
        return b;
    }
    
    /**
     * Given an icon and action, creates a toggle button that triggers the action.
     */
    public Gtk.Button create_toggle_button(string? icon_name, string action_name) {
        Gtk.ToggleButton b = new Gtk.ToggleButton();
        setup_button(b, icon_name, action_name);
        
        return b;
    }
    
    /**
     * Given an icon, menu, and action, creates a button that triggers the menu and the action.
     */
    public Gtk.MenuButton create_menu_button(string? icon_name, Gtk.Menu? menu, string action_name) {
        Gtk.MenuButton b = new Gtk.MenuButton();
        setup_button(b, icon_name, action_name);
        b.popup = menu;
        
        return b;
    }
    
    /**
     * Given a list of buttons, creates a "pill-style" tool item that can be appended to this
     * toolbar.  Optionally adds a spacer to the left.
     */
    public Gtk.ToolItem create_pill_buttons(Gee.Collection<Gtk.Button> buttons,
        bool left_spacer = true, bool right_spacer = false) {
        Gtk.Box box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        
        if (buttons.size > 1) {
            box.get_style_context().add_class(Gtk.STYLE_CLASS_RAISED);
            box.get_style_context().add_class(Gtk.STYLE_CLASS_LINKED);
        }
        
        int i = 0;
        foreach(Gtk.Button button in buttons) {
            box.add(button);
            
            // Place the right spacer on the button itself.  This way if the button is not displayed,
            // the spacer will not appear.
            if (i == buttons.size - 1 && right_spacer)
                button.set_margin_right(12);
            
            i++;
        }
        
        Gtk.ToolItem tool_item = new Gtk.ToolItem();
        tool_item.add(box);
        
        if (left_spacer)
            box.set_margin_left(12);
        
        return tool_item;
    }
    
    /**
     * Computes the margin for each icon (shamelessly stolen from Nautilus.)
     */
    public int get_icon_margin() {
        Gtk.IconSize toolbar_size = get_icon_size();
        int toolbar_size_px, menu_size_px;
        
        Gtk.icon_size_lookup(Gtk.IconSize.MENU, out menu_size_px, null);
        Gtk.icon_size_lookup(toolbar_size, out toolbar_size_px, null);
        
        return Geary.Numeric.int_floor((int) ((toolbar_size_px - menu_size_px) / 2.0), 0);
    }
    
    /**
     * Returns an expandable spacer item.
     */
    public Gtk.ToolItem create_spacer() {
        Gtk.ToolItem spacer = new Gtk.ToolItem();
        spacer.set_expand(true);
        
        return spacer;
    }
}

