#include "my_application.h"

#include <flutter_linux/flutter_linux.h>

#include <cstring>

#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  FlMethodChannel* shortcut_channel;
  gboolean shortcut_capture_enabled;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

static const gchar* shortcut_key_for_event(GdkEventKey* event) {
  switch (event->hardware_keycode) {
    case 41:
      return "keyF";
    case 40:
      return "keyD";
    case 58:
      return "keyM";
    case 27:
      return "keyR";
    case 54:
      return "keyC";
    case 24:
      return "keyQ";
    case 26:
      return "keyE";
    case 28:
      return "keyT";
    case 42:
      return "keyG";
    case 56:
      return "keyB";
    case 57:
      return "keyN";
    case 111:
      return "arrowUp";
    case 116:
      return "arrowDown";
    default:
      break;
  }

  switch (event->keyval) {
    case GDK_KEY_f:
    case GDK_KEY_F:
      return "keyF";
    case GDK_KEY_d:
    case GDK_KEY_D:
      return "keyD";
    case GDK_KEY_m:
    case GDK_KEY_M:
      return "keyM";
    case GDK_KEY_r:
    case GDK_KEY_R:
      return "keyR";
    case GDK_KEY_c:
    case GDK_KEY_C:
      return "keyC";
    case GDK_KEY_q:
    case GDK_KEY_Q:
      return "keyQ";
    case GDK_KEY_e:
    case GDK_KEY_E:
      return "keyE";
    case GDK_KEY_t:
    case GDK_KEY_T:
      return "keyT";
    case GDK_KEY_g:
    case GDK_KEY_G:
      return "keyG";
    case GDK_KEY_b:
    case GDK_KEY_B:
      return "keyB";
    case GDK_KEY_n:
    case GDK_KEY_N:
      return "keyN";
    case GDK_KEY_Up:
      return "arrowUp";
    case GDK_KEY_Down:
      return "arrowDown";
    default:
      return nullptr;
  }
}

static gboolean shortcut_key_press_cb(GtkWidget* widget,
                                      GdkEventKey* event,
                                      gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  const gchar* key = shortcut_key_for_event(event);
  if (key == nullptr || self->shortcut_channel == nullptr) {
    return FALSE;
  }

  g_autoptr(FlValue) arguments = fl_value_new_map();
  fl_value_set_string_take(arguments, "key", fl_value_new_string(key));
  fl_method_channel_invoke_method(self->shortcut_channel, "shortcutKeyDown",
                                  arguments, nullptr, nullptr, nullptr);
  return self->shortcut_capture_enabled;
}

static void shortcut_method_call_cb(FlMethodChannel* channel,
                                    FlMethodCall* method_call,
                                    gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  const gchar* method = fl_method_call_get_name(method_call);
  if (strcmp(method, "setShortcutCaptureEnabled") == 0) {
    FlValue* arguments = fl_method_call_get_args(method_call);
    FlValue* enabled = nullptr;
    if (arguments != nullptr &&
        fl_value_get_type(arguments) == FL_VALUE_TYPE_MAP) {
      enabled = fl_value_lookup_string(arguments, "enabled");
    }
    if (enabled != nullptr && fl_value_get_type(enabled) == FL_VALUE_TYPE_BOOL) {
      self->shortcut_capture_enabled = fl_value_get_bool(enabled);
    }
    g_autoptr(FlMethodResponse) response =
        FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
    fl_method_call_respond(method_call, response, nullptr);
    return;
  }

  g_autoptr(FlMethodResponse) response =
      FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  fl_method_call_respond(method_call, response, nullptr);
}

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "simple_live_app");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "simple_live_app");
  }

  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  self->shortcut_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "simple_live/desktop_shortcuts",
      FL_METHOD_CODEC(fl_standard_method_codec_new()));
  fl_method_channel_set_method_call_handler(
      self->shortcut_channel, shortcut_method_call_cb, self, nullptr);
  g_signal_connect(view, "key-press-event", G_CALLBACK(shortcut_key_press_cb),
                   self);

  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));
  fl_method_channel_invoke_method(self->shortcut_channel,
                                  "shortcutCaptureStateRequested", nullptr,
                                  nullptr, nullptr, nullptr);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_object(&self->shortcut_channel);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {
  self->shortcut_channel = nullptr;
  self->shortcut_capture_enabled = FALSE;
}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond the binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
