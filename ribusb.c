#include <ruby.h>
#include <libusb.h>

static VALUE rb_mRibUSB;
static VALUE rb_cBus;
static VALUE rb_cDevice;
static VALUE Errors;

/*
 * Opaque structure for the RibUSB::Bus class
 */
struct usb_t {
  libusb_context *context;
};

/*
 * Opaque structure for the RibUSB::Device class
 */
struct device_t {
  libusb_device *device;
  libusb_device_handle *handle;
};

static VALUE cDevice_new (libusb_device *device);



/******************************************************
 * RibUSB method definitions                          *
 ******************************************************/

int find_error (int number, char **name, char **text)
{
  struct error_t {
    int number;
    char *name;
    char *text;
  };
  static const struct error_t error_list[] = {
    { LIBUSB_SUCCESS, "LIBUSB_SUCCESS", "success (no error)" },
    { LIBUSB_ERROR_IO, "LIBUSB_ERROR_IO", "input/output error" },
    { LIBUSB_ERROR_INVALID_PARAM, "LIBUSB_ERROR_INVALID_PARAM", "invalid parameter" },
    { LIBUSB_ERROR_ACCESS, "LIBUSB_ERROR_ACCESS", "access denied (insuffucient permissions)" },
    { LIBUSB_ERROR_NO_DEVICE, "LIBUSB_ERROR_NO_DEVICE", "no such device" },
    { LIBUSB_ERROR_NOT_FOUND, "LIBUSB_ERROR_NOT_FOUND", "entity not found" },
    { LIBUSB_ERROR_BUSY, "LIBUSB_ERROR_BUSY", "resource busy" },
    { LIBUSB_ERROR_TIMEOUT, "LIBUSB_ERROR_TIMEOUT", "operation timed out" },
    { LIBUSB_ERROR_OVERFLOW, "LIBUSB_ERROR_OVERFLOW", "overflow" },
    { LIBUSB_ERROR_PIPE, "LIBUSB_ERROR_PIPE", "pipe error" },
    { LIBUSB_ERROR_INTERRUPTED, "LIBUSB_ERROR_INTERRUPTED", "system call interrupted (perhaps due to signal)" },
    { LIBUSB_ERROR_NO_MEM, "LIBUSB_ERROR_NO_MEM", "insufficient memory" },
    { LIBUSB_ERROR_NOT_SUPPORTED, "LIBUSB_ERROR_NOT_SUPPORTED", "operation not supported or unimplemented on this platform" },
    { LIBUSB_ERROR_OTHER, "LIBUSB_ERROR_OTHER", "other error" }
  };
  static const int n_error_list = sizeof (error_list) / sizeof (struct error_t);
  static int i;

  for (i = 0; i < n_error_list; i ++)
    if (number == error_list[i].number) {
      if (name)
	*name = error_list[i].name;
      if (text)
	*text = error_list[i].text;
      return 1;
      break;
    }
  return 0;
}

char *find_error_text (int number)
{
  char *text;
  static char unknown[] = "unknown error number";

  if (find_error (number, NULL, &text))
    return text;
  else
    return unknown;
}

/*
 * call-seq:
 *   RibUSB.findError(number) -> [name, text]
 *
 * Find the textual error description corresponding to a _libusb_ error code.
 *
 * - +number+ is an integer containing the error returned by a _libusb_ function.
 * - +name+ is a +String+ containing the name of the error as used in the C header file <tt>libusb.h</tt>.
 * - +text+ is a verbose description of the error, in English, using lower-case letters and no punctuation.
 *
 * On success (if the error number is valid), returns an array of two strings, otherwise raises an error and returns +nil+. A value <tt>0</tt> for +number+ is a valid error number. All valid values for +number+ are non-positive.
 */
static VALUE mRibUSB_findError (VALUE self, VALUE number)
{
  int error;
  char *name, *text;
  VALUE array;

  error = NUM2INT(number);
  if (find_error (error, &name, &text)) {
    array = rb_ary_new2 (2);
    rb_ary_store (array, 0, rb_str_new2 (name));
    rb_ary_store (array, 1, rb_str_new2 (text));
    return array;
  } else {
    rb_raise (rb_eRuntimeError, "Error number %i does not exist.", error);
    return Qnil;
  }
}



/******************************************************
 * RibUSB::Bus method definitions                     *
 ******************************************************/

void cBus_free (struct usb_t *u)
{
  libusb_exit (u->context);

  free (u);
}

/*
 * call-seq:
 *   RibUSB::Bus.new -> bus
 *
 * Create an instance of RibUSB::Bus.
 *
 * Effectively creates a _libusb_ context (the context itself being stored in an opaque structure). The memory associated with the bus is automatically freed on garbage collection when possible.
 *
 * If successful, returns the bus object, otherwise raises an error and returns +nil+.
 */
static VALUE cBus_new (VALUE self)
{
  libusb_context *context;
  struct usb_t *u;
  int res;
  VALUE object;

  res = libusb_init (&context);
  if (res) {
    rb_raise (rb_eRuntimeError, "Failed to initialize libusb: %s.", find_error_text (res));
    return Qnil;
  } else {
    u = (struct usb_t *) malloc (sizeof (struct usb_t));
    if (!u) {
      rb_raise (rb_eRuntimeError, "Failed to allocate memory for RibUSB::Bus object.");
      return Qnil;
    }
    u->context = context;
    object = Data_Wrap_Struct (rb_cBus, NULL, cBus_free, u);
    rb_obj_call_init (object, 0, 0);
    return object;
  }
}

/*
 * call-seq:
 *   bus.setDebug(level) -> nil
 *   bus.debug=level -> nil
 *
 * Set the debug level of the current _libusb_ context.
 *
 * - +level+ is a +FixNum+ with a sensible range from 0 to 4.
 *
 * Returns +nil+ and never raises an exception.
 */
static VALUE cBus_setDebug (VALUE self, VALUE level)
{
  struct usb_t *u;

  Data_Get_Struct (self, struct usb_t, u);
  libusb_set_debug (u->context, NUM2INT(level));
  return Qnil;
}

/*
 * call-seq:
 *   bus.deviceList -> list
 *
 * Obtain the list of devices currently attached to the USB system.
 *
 * On success, returns an array of RibUSB::Device with one entry for each device, otherwise raises an error and returns +nil+.
 *
 * Note: this list provides no information whatsoever on whether or not any given device can be accessed. Permissions and use by other software can prevent access to any device.
 */
static VALUE cBus_deviceList (VALUE self)
{
  struct usb_t *u;
  libusb_device **list;
  ssize_t res;
  VALUE device, array;
  int i;

  Data_Get_Struct (self, struct usb_t, u);

  res = libusb_get_device_list (u->context, &list);

  if (res < 0) {
    rb_raise (rb_eRuntimeError, "Failed to allocate memory for list of devices: %s.", find_error_text (res));
    return Qnil;
  }

  array = rb_ary_new2 (res);

  for (i = 0; i < res; i ++) {
    device = cDevice_new (list[i]);
    rb_ary_store (array, i, device);
  }

  libusb_free_device_list (list, 1);

  return array;
}



/******************************************************
 * RibUSB::Device method definitions                  *
 ******************************************************/

void cDevice_free (struct device_t *d)
{
  if (d->handle)
    libusb_close (d->handle);

  libusb_unref_device (d->device);

  free (d);
}

static VALUE cDevice_new (libusb_device *device)
{
  struct device_t *d;
  VALUE object;

  d = (struct device_t *) malloc (sizeof (struct device_t));
  if (!d) {
    rb_raise (rb_eRuntimeError, "Failed to allocate memory for RibUSB::Device object.");
    return Qnil;
  }
  libusb_ref_device (device);
  d->device = device;
  d->handle = NULL;
  object = Data_Wrap_Struct (rb_cDevice, NULL, cDevice_free, d);
  rb_obj_call_init (object, 0, 0);
  return object;
}

/*
 * call-seq:
 *   device.getBusNumber -> bus_number
 *
 * Get bus number.
 *
 * On success, returns the USB bus number (+FixNum+) the device is connected to, otherwise raises an error and returns +nil+.
 */
static VALUE cDevice_getBusNumber (VALUE self)
{
  struct device_t *d;
  int res;

  Data_Get_Struct (self, struct device_t, d);
  res = libusb_get_bus_number (d->device);
  if (res < 0) {
    rb_raise (rb_eRuntimeError, "Failed to retrieve device bus number: %s.", find_error_text (res));
    return Qnil;
  }
  return INT2NUM(res);
}

/*
 * call-seq:
 *   device.getDeviceAddress -> address
 *
 * Get device address.
 *
 * On success, returns the USB address on the bus (+FixNum+), otherwise raises an error and returns +nil+.
 */
static VALUE cDevice_getDeviceAddress (VALUE self)
{
  struct device_t *d;
  int res;

  Data_Get_Struct (self, struct device_t, d);
  res = libusb_get_device_address (d->device);
  if (res < 0) {
    rb_raise (rb_eRuntimeError, "Failed to retrieve device address: %s.", find_error_text (res));
    return Qnil;
  }
  return INT2NUM(res);
}

/*
 * call-seq:
 *   device.getMaxPacketSize(endpoint) -> max_packet_size
 *
 * Get maximum packet size.
 *
 * - +endpoint+ is a +FixNum+ containing the endpoint number.
 *
 * On success, returns the maximum packet size of the endpoint (+FixNum+), otherwise raises an error and returns +nil+.
 */
static VALUE cDevice_getMaxPacketSize (VALUE self, VALUE endpoint)
{
  struct device_t *d;
  int res;

  Data_Get_Struct (self, struct device_t, d);
  res = libusb_get_max_packet_size (d->device, NUM2INT(endpoint));
  if (res < 0) {
    rb_raise (rb_eRuntimeError, "Failed to retrieve maximum packet size of endpoint: %s.", find_error_text (res));
    return Qnil;
  }
  return INT2NUM(res);
}

/*
 * call-seq:
 *   device.getConfiguration -> configuration
 *
 * Get currently active configuration.
 *
 * On success, returns the bConfigurationValue of the active configuration of the device (+FixNum+), otherwise raises an error and returns +nil+.
 */
static VALUE cDevice_getConfiguration (VALUE self)
{
  struct device_t *d;
  int res;
  int c;

  Data_Get_Struct (self, struct device_t, d);
  if (d->handle == NULL) {
    res = libusb_open (d->device, &(d->handle));
    if (res < 0) {
      rb_raise (rb_eRuntimeError, "Failed to open USB device: %s.", find_error_text (res));
      return Qnil;
    }
  }
  res = libusb_get_configuration (d->handle, &c);
  if (res < 0) {
    rb_raise (rb_eRuntimeError, "Failed to obtain configuration value: %s.", find_error_text (res));
    return Qnil;
  }
  return INT2NUM(c);
}

/*
 * call-seq:
 *   device.setConfiguration(configuration) -> nil
 *   device.configuration=(configuration) -> nil
 *
 * Set active configuration.
 *
 * - +configuration+ is a +FixNum+ containing the configuration number.
 *
 * Returns +nil+ in any case, and raises an error on failure.
 */
static VALUE cDevice_setConfiguration (VALUE self, VALUE configuration)
{
  struct device_t *d;
  int res;

  Data_Get_Struct (self, struct device_t, d);
  if (d->handle == NULL) {
    res = libusb_open (d->device, &(d->handle));
    if (res < 0) {
      rb_raise (rb_eRuntimeError, "Failed to open USB device: %s.", find_error_text (res));
      return Qnil;
    }
  }
  res = libusb_set_configuration (d->handle, NUM2INT(configuration));
  if (res < 0) {
    rb_raise (rb_eRuntimeError, "Failed to set configuration: %s.", find_error_text (res));
    return Qnil;
  }
  return Qnil;
}

/*
 * call-seq:
 *   device.claimInterface(interface) -> nil
 *
 * Claim interface.
 *
 * - +interface+ is a +FixNum+ containing the interface number.
 *
 * Returns +nil+ in any case, and raises an error on failure.
 */
static VALUE cDevice_claimInterface (VALUE self, VALUE interface)
{
  struct device_t *d;
  int res;

  Data_Get_Struct (self, struct device_t, d);
  if (d->handle == NULL) {
    res = libusb_open (d->device, &(d->handle));
    if (res < 0) {
      rb_raise (rb_eRuntimeError, "Failed to open USB device: %s.", find_error_text (res));
      return Qnil;
    }
  }
  res = libusb_claim_interface (d->handle, NUM2INT(interface));
  if (res < 0) {
    rb_raise (rb_eRuntimeError, "Failed to claim interface: %s.", find_error_text (res));
    return Qnil;
  }
  return Qnil;
}

/*
 * call-seq:
 *   device.releaseInterface(interface) -> nil
 * Release interface.
 *
 * - +interface+ is a +FixNum+ containing the interface number.
 *
 * Returns +nil+ in any case, and raises an error on failure.
 */
static VALUE cDevice_releaseInterface (VALUE self, VALUE interface)
{
  struct device_t *d;
  int res;

  Data_Get_Struct (self, struct device_t, d);
  if (d->handle == NULL) {
    res = libusb_open (d->device, &(d->handle));
    if (res < 0) {
      rb_raise (rb_eRuntimeError, "Failed to open USB device: %s.", find_error_text (res));
      return Qnil;
    }
  }
  res = libusb_release_interface (d->handle, NUM2INT(interface));
  if (res < 0) {
    rb_raise (rb_eRuntimeError, "Failed to release interface: %s.", find_error_text (res));
    return Qnil;
  }
  return Qnil;
}

/*
 * call-seq:
 *   device.setInterfaceAltSetting(interface, setting) -> nil
 *
 * Set alternate setting for an interface.
 *
 * - +interface+ is a +FixNum+ containing the interface number.
 * - +setting+ is a +FixNum+ containing the alternate setting number.
 *
 * Returns +nil+ in any case, and raises an error on failure.
 */
static VALUE cDevice_setInterfaceAltSetting (VALUE self, VALUE interface, VALUE setting)
{
  struct device_t *d;
  int res;

  Data_Get_Struct (self, struct device_t, d);
  if (d->handle == NULL) {
    res = libusb_open (d->device, &(d->handle));
    if (res < 0) {
      rb_raise (rb_eRuntimeError, "Failed to open USB device: %s.", find_error_text (res));
      return Qnil;
    }
  }
  res = libusb_set_interface_alt_setting (d->handle, NUM2INT(interface), NUM2INT(setting));
  if (res < 0) {
    rb_raise (rb_eRuntimeError, "Failed to set interface alternate setting: %s.", find_error_text (res));
    return Qnil;
  }
  return INT2NUM(0);
}

/*
 * call-seq:
 *   device.clearHalt(endpoint) -> nil
 *
 * Clear halt/stall condition for an endpoint.
 *
 * - +endpoint+ is a +FixNum+ containing the endpoint number.
 *
 * Returns +nil+ in any case, and raises an error on failure.
 */
static VALUE cDevice_clearHalt (VALUE self, VALUE endpoint)
{
  struct device_t *d;
  int res;

  Data_Get_Struct (self, struct device_t, d);
  if (d->handle == NULL) {
    res = libusb_open (d->device, &(d->handle));
    if (res < 0) {
      rb_raise (rb_eRuntimeError, "Failed to open USB device: %s.", find_error_text (res));
      return Qnil;
    }
  }
  res = libusb_clear_halt (d->handle, NUM2INT(endpoint));
  if (res < 0) {
    rb_raise (rb_eRuntimeError, "Failed to clear halt/stall condition: %s.", find_error_text (res));
    return Qnil;
  }
  return INT2NUM(0);
}

/*
 * call-seq: device.resetDevice -> nil
 *
 * Reset device.
 *
 * Returns +nil+ in any case, and raises an error on failure.
 */
static VALUE cDevice_resetDevice (VALUE self)
{
  struct device_t *d;
  int res;

  Data_Get_Struct (self, struct device_t, d);
  if (d->handle == NULL) {
    res = libusb_open (d->device, &(d->handle));
    if (res < 0) {
      rb_raise (rb_eRuntimeError, "Failed to open USB device: %s.", find_error_text (res));
      return Qnil;
    }
  }
  res = libusb_reset_device (d->handle);
  if (res < 0) {
    rb_raise (rb_eRuntimeError, "Failed to reset device: %s.", find_error_text (res));
    return Qnil;
  }
  return INT2NUM(0);
}

/*
 * call-seq:
 *   device.kernelDriverActive?(interface) -> result
 *
 * Determine if a kernel driver is active on a given interface.
 *
 * - +interface+ is a +FixNum+ containing the interface number.
 *
 * On success, returns whether or not the device interface is claimed by a kernel driver (+true+ or +false+), otherwise raises an error and returns +nil+.
 */
static VALUE cDevice_kernelDriverActiveQ (VALUE self, VALUE interface)
{
  struct device_t *d;
  int res;

  Data_Get_Struct (self, struct device_t, d);
  if (d->handle == NULL) {
    res = libusb_open (d->device, &(d->handle));
    if (res < 0) {
      rb_raise (rb_eRuntimeError, "Failed to open USB device: %s.", find_error_text (res));
      return Qnil;
    }
  }
  res = libusb_kernel_driver_active (d->handle, NUM2INT(interface));
  if (res < 0) {
    rb_raise (rb_eRuntimeError, "Failed to determine whether a kernel driver is active on interface: %s.", find_error_text (res));
    return Qnil;
  } else if (res == 1)
    return Qtrue;
  else
    return Qfalse;
}

/*
 * call-seq:
 *   device.detachKernelDriver(interface) -> nil
 *
 * Detach a kernel driver from an interface.
 *
 * - +interface+ is a +FixNum+ containing the interface number.
 *
 * Returns +nil+ in any case, and raises an error on failure.
 */
static VALUE cDevice_detach_kernel_driver (VALUE self, VALUE interface)
{
  struct device_t *d;
  int res;

  Data_Get_Struct (self, struct device_t, d);
  if (d->handle == NULL) {
    res = libusb_open (d->device, &(d->handle));
    if (res < 0) {
      rb_raise (rb_eRuntimeError, "Failed to open USB device: %s.", find_error_text (res));
      return Qnil;
    }
  }
  res = libusb_detach_kernel_driver (d->handle, NUM2INT(interface));
  if (res < 0) {
    rb_raise (rb_eRuntimeError, "Failed to detach kernel driver: %s.", find_error_text (res));
    return Qnil;
  }
  return Qnil;
}

/*
 * call-seq:
 *   device.attachKernelDriver(interface) -> nil
 *
 * Re-attach a kernel driver from an interface.
 *
 * - +interface+ is a +FixNum+ containing the interface number.
 *
 * Returns +nil+ in any case, and raises an error on failure.
 */
static VALUE cDevice_attach_kernel_driver (VALUE self, VALUE interface)
{
  struct device_t *d;
  int res;

  Data_Get_Struct (self, struct device_t, d);
  if (d->handle == NULL) {
    res = libusb_open (d->device, &(d->handle));
    if (res < 0) {
      rb_raise (rb_eRuntimeError, "Failed to open USB device: %s.", find_error_text (res));
      return Qnil;
    }
  }
  res = libusb_attach_kernel_driver (d->handle, NUM2INT(interface));
  if (res < 0) {
    rb_raise (rb_eRuntimeError, "Failed to re-attach kernel driver: %s.", find_error_text (res));
    return Qnil;
  }
  return Qnil;
}



/******************************************************
 * RibUSB -- an interface to _libusb_, API version 1.0
 ******************************************************/
void Init_ribusb()
{
  rb_mRibUSB = rb_define_module ("RibUSB");

  rb_define_singleton_method (rb_mRibUSB, "findError", mRibUSB_findError, 1);

  /* RibUSB::Bus -- a class for _libusb_ bus handling sessions */
  rb_cBus = rb_define_class_under (rb_mRibUSB, "Bus", rb_cObject);
  rb_define_singleton_method (rb_cBus, "new", cBus_new, 0);
  rb_define_method (rb_cBus, "setDebug", cBus_setDebug, 1);
  rb_define_alias (rb_cBus, "debug=", "setDebug");
  rb_define_method (rb_cBus, "deviceList", cBus_deviceList, 0);

  /* RibUSB::Device -- a class for individual USB devices accessed through _libusb_ */
  rb_cDevice = rb_define_class_under (rb_mRibUSB, "Device", rb_cObject);
  rb_define_method (rb_cDevice, "getBusNumber", cDevice_getBusNumber, 0);
  rb_define_method (rb_cDevice, "busNumber", cDevice_getBusNumber, 0);
  rb_define_method (rb_cDevice, "getDeviceAddress", cDevice_getDeviceAddress, 0);
  rb_define_method (rb_cDevice, "deviceAddress", cDevice_getDeviceAddress, 0);
  rb_define_method (rb_cDevice, "getMaxPacketSize", cDevice_getMaxPacketSize, 1);
  rb_define_method (rb_cDevice, "maxPacketSize", cDevice_getMaxPacketSize, 1);
  rb_define_method (rb_cDevice, "getConfiguration", cDevice_getConfiguration, 0);
  rb_define_method (rb_cDevice, "configuration", cDevice_getConfiguration, 0);
  rb_define_method (rb_cDevice, "setConfiguration", cDevice_setConfiguration, 1);
  rb_define_alias (rb_cDevice, "configuration=", "setConfiguration");
  rb_define_method (rb_cDevice, "claimInterface", cDevice_claimInterface, 1);
  rb_define_method (rb_cDevice, "releaseInterface", cDevice_releaseInterface, 1);
  rb_define_method (rb_cDevice, "setInterfaceAltSetting", cDevice_setInterfaceAltSetting, 2);
  rb_define_method (rb_cDevice, "clearHalt", cDevice_clearHalt, 1);
  rb_define_method (rb_cDevice, "resetDevice", cDevice_resetDevice, 0);
  rb_define_method (rb_cDevice, "kernelDriverActive?", cDevice_kernelDriverActiveQ, 1);
  rb_define_method (rb_cDevice, "detachKernelDriver", cDevice_detach_kernel_driver, 1);
  rb_define_method (rb_cDevice, "attachKernelDriver", cDevice_attach_kernel_driver, 1);
}
