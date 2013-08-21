/* Copyright 2011-2013 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

public class ComposerToolbar : PillToolbar {
    public ComposerToolbar(Gtk.ActionGroup toolbar_action_group, Gtk.Menu menu) {
        base(toolbar_action_group);
        
        Gee.List<Gtk.Button> insert = new Gee.ArrayList<Gtk.Button>();
        
        // Font formatting.
        insert.add(create_toggle_button(null, ComposerWindow.ACTION_BOLD));
        insert.add(create_toggle_button(null, ComposerWindow.ACTION_ITALIC));
        insert.add(create_toggle_button(null, ComposerWindow.ACTION_UNDERLINE));
        insert.add(create_toggle_button(null, ComposerWindow.ACTION_STRIKETHROUGH));
        add(create_pill_buttons(insert, false));
        
        // Indent level.
        insert.clear();
        insert.add(create_toolbar_button(null, ComposerWindow.ACTION_INDENT));
        insert.add(create_toolbar_button(null, ComposerWindow.ACTION_OUTDENT));
        add(create_pill_buttons(insert));
        
        // Link.
        insert.clear();
        insert.add(create_toolbar_button(null, ComposerWindow.ACTION_INSERT_LINK));
        add(create_pill_buttons(insert));
        
        // Remove formatting.
        insert.clear();
        insert.add(create_toolbar_button(null, ComposerWindow.ACTION_REMOVE_FORMAT));
        add(create_pill_buttons(insert));
        
        // Spacer.
        add(create_spacer());
        
        // Menu.
        insert.clear();
        insert.add(create_menu_button(null, menu, ComposerWindow.ACTION_MENU));
        add(create_pill_buttons(insert));
    }
}

