/* ========================================================================= */
/*
   RibUSB -- Ruby bindings to libusb.

   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License as
   published by the Free Software Foundation; version 2 of the License.

   This program is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place - Suite 330, Boston,
   MA 02111-1307, USA.

   This program is copyright by András G. Major, 2009.
   Please visit the project website at http://ribusb.rubyforge.org/
   for support.
*/
/* ========================================================================= */

#include <ruby.h>
#include <libusb.h>

/******************************************************
 * global variables                                   *
 ******************************************************/

static VALUE rb_mRibUSB;
static VALUE rb_cBus;
static VALUE rb_cDevice;
static VALUE rb_cDeviceDescriptor;
static VALUE rb_cConfigDescriptor;
static VALUE rb_cInterface;
static VALUE rb_cInterfaceDescriptor;
static VALUE rb_cEndpointDescriptor;
static VALUE rb_cTransfer;



/******************************************************
 * structures for classes                             *
 ******************************************************/

/*
 * Opaque structure for the RibUSB::Bus class
 */
struct usb_t {
  struct libusb_context *context;
};

/*
 * Opaque structure for the RibUSB::Device class
 */
struct device_t {
  struct libusb_device *device;
  struct libusb_device_handle *handle;
};

/*
 * Opaque structure for the RibUSB::DeviceDescriptor class
 */
struct device_descriptor_t {
  struct libusb_device_descriptor *descriptor;
};

/*
 * Opaque structure for the RibUSB::ConfigDescriptor class
 */
struct config_descriptor_t {
  struct libusb_config_descriptor *descriptor;
};

/*
 * Opaque structure for the RibUSB::Interface class
 */
struct interface_t {
  struct libusb_interface *interface;
};

/*
 * Opaque structure for the RibUSB::InterfaceDescriptor class
 */
struct interface_descriptor_t {
  struct libusb_interface_descriptor *descriptor;
};

/*
 * Opaque structure for the RibUSB::EndpointDescriptor class
 */
struct endpoint_descriptor_t {
  struct libusb_endpoint_descriptor *descriptor;
};

/*
 * Opaque structure for the RibUSB::Transfer class
 */
struct transfer_t {
  struct libusb_transfer *transfer;
  void *buffer;
};

/* XXXXX remove? */
/*
 * Opaque structure for the RibUSB::ControlSetup class
 */
struct control_setup_t {
  struct libusb_control_setup *setup;
};

/* XXXXX remove? */
/*
 * Opaque structure for the RibUSB::IsoPacketDescriptor class
 */
struct iso_packet_descriptor_t {
  struct libusb_iso_packet_descriptor *descriptor;
};



/******************************************************
 * internal prototypes                                *
 ******************************************************/
static VALUE cDevice_new (struct libusb_device *device);
static VALUE cDeviceDescriptor_new (struct libusb_device_descriptor *descriptor);
static VALUE cConfigDescriptor_new (struct libusb_config_descriptor *descriptor);
static VALUE cInterface_new (struct libusb_interface *interface);
static VALUE cInterfaceDescriptor_new (struct libusb_interface_descriptor *descriptor);
static VALUE cEndpointDescriptor_new (struct libusb_endpoint_descriptor *descriptor);



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
 * On success (if the error number is valid), returns an array of two strings, otherwise raises an exception and returns +nil+. A value <tt>0</tt> for +number+ is a valid error number. All valid values for +number+ are non-positive.
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
 * If successful, returns the bus object, otherwise raises an exception and returns either +nil+ or the _libusb_ error code (+FixNum+).
 */
static VALUE cBus_new (VALUE self)
{
  struct libusb_context *context;
  struct usb_t *u;
  int res;
  VALUE object;

  res = libusb_init (&context);
  if (res) {
    rb_raise (rb_eRuntimeError, "Failed to initialize libusb: %s.", find_error_text (res));
    return INT2NUM(res);
  }
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

/*
 * call-seq:
 *   bus.setDebug(level) -> nil
 *   bus.debug=level -> nil
 *
 * Set the debug level of the current _libusb_ context.
 *
 * - +level+ is a +FixNum+ with a sensible range from 0 to 3.
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
 *   bus.getDeviceList -> list
 *   bus.deviceList -> list
 *
 * Obtain the list of devices currently attached to the USB system.
 *
 * On success, returns an array of RibUSB::Device with one entry for each device, otherwise raises an exception and returns the _libusb_ error code (+FixNum+).
 *
 * Note: this list provides no information whatsoever on whether or not any given device can be accessed. Insufficient privilege and use by other software can prevent access to any device.
 */
static VALUE cBus_getDeviceList (VALUE self)
{
  struct usb_t *u;
  struct libusb_device **list;
  ssize_t res;
  VALUE device, array;
  int i;

  Data_Get_Struct (self, struct usb_t, u);

  res = libusb_get_device_list (u->context, &list);

  if (res < 0) {
    rb_raise (rb_eRuntimeError, "Failed to allocate memory for list of devices: %s.", find_error_text (res));
    return INT2NUM(res);
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

static VALUE cDevice_new (struct libusb_device *device)
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
 *   device.busNumber -> bus_number
 *
 * Get bus number.
 *
 * On success, returns the USB bus number (+FixNum+) the device is connected to, otherwise raises an exception and returns the _libusb_ error code (+FixNum+).
 */
static VALUE cDevice_getBusNumber (VALUE self)
{
  struct device_t *d;
  int res;

  Data_Get_Struct (self, struct device_t, d);
  res = libusb_get_bus_number (d->device);
  if (res < 0)
    rb_raise (rb_eRuntimeError, "Failed to retrieve device bus number: %s.", find_error_text (res));
  return INT2NUM(res);
}

/*
 * call-seq:
 *   device.getDeviceAddress -> address
 *   device.deviceAddress -> address
 *
 * Get device address.
 *
 * On success, returns the USB address on the bus (+FixNum+), otherwise raises an exception and returns the _libusb_ error code (+FixNum+).
 */
static VALUE cDevice_getDeviceAddress (VALUE self)
{
  struct device_t *d;
  int res;

  Data_Get_Struct (self, struct device_t, d);
  res = libusb_get_device_address (d->device);
  if (res < 0)
    rb_raise (rb_eRuntimeError, "Failed to retrieve device address: %s.", find_error_text (res));
  return INT2NUM(res);
}

/*
 * call-seq:
 *   device.getMaxPacketSize(endpoint) -> max_packet_size
 *   device.maxPacketSize(endpoint) -> max_packet_size
 *
 * Get maximum packet size.
 *
 * - +endpoint+ is a +FixNum+ containing the endpoint number.
 *
 * On success, returns the maximum packet size of the endpoint (+FixNum+), otherwise raises an exception and returns the _libusb_ error code (+FixNum+).
 */
static VALUE cDevice_getMaxPacketSize (VALUE self, VALUE endpoint)
{
  struct device_t *d;
  int res;

  Data_Get_Struct (self, struct device_t, d);
  res = libusb_get_max_packet_size (d->device, NUM2INT(endpoint));
  if (res < 0)
    rb_raise (rb_eRuntimeError, "Failed to retrieve maximum packet size of endpoint: %s.", find_error_text (res));
  return INT2NUM(res);
}

/*
 * call-seq:
 *   device.getConfiguration -> configuration
 *   device.configuration -> configuration
 *
 * Get currently active configuration.
 *
 * On success, returns the bConfigurationValue of the active configuration of the device (+FixNum+), otherwise raises an exception and returns the _libusb_ error code (+FixNum+).
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
      return INT2NUM(res);
    }
  }
  res = libusb_get_configuration (d->handle, &c);
  if (res < 0)
    rb_raise (rb_eRuntimeError, "Failed to obtain configuration value: %s.", find_error_text (res));
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
 * Returns +nil+ in any case, and raises an exception on failure.
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
      return INT2NUM(res);
    }
  }
  res = libusb_set_configuration (d->handle, NUM2INT(configuration));
  if (res < 0)
    rb_raise (rb_eRuntimeError, "Failed to set configuration: %s.", find_error_text (res));
  return INT2NUM(res);
}

/*
 * call-seq:
 *   device.claimInterface(interface) -> nil
 *
 * Claim interface.
 *
 * - +interface+ is a +FixNum+ containing the interface number.
 *
 * Returns +nil+ in any case, and raises an exception on failure.
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
      return INT2NUM(res);
    }
  }
  res = libusb_claim_interface (d->handle, NUM2INT(interface));
  if (res < 0)
    rb_raise (rb_eRuntimeError, "Failed to claim interface: %s.", find_error_text (res));
  return INT2NUM(res);
}

/*
 * call-seq:
 *   device.releaseInterface(interface) -> nil
 * Release interface.
 *
 * - +interface+ is a +FixNum+ containing the interface number.
 *
 * Returns +nil+ in any case, and raises an exception on failure.
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
      return INT2NUM(res);
    }
  }
  res = libusb_release_interface (d->handle, NUM2INT(interface));
  if (res < 0)
    rb_raise (rb_eRuntimeError, "Failed to release interface: %s.", find_error_text (res));
  return INT2NUM(res);
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
 * Returns +nil+ in any case, and raises an exception on failure.
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
      return INT2NUM(res);
    }
  }
  res = libusb_set_interface_alt_setting (d->handle, NUM2INT(interface), NUM2INT(setting));
  if (res < 0)
    rb_raise (rb_eRuntimeError, "Failed to set interface alternate setting: %s.", find_error_text (res));
  return INT2NUM(res);
}

/*
 * call-seq:
 *   device.clearHalt(endpoint) -> nil
 *
 * Clear halt/stall condition for an endpoint.
 *
 * - +endpoint+ is a +FixNum+ containing the endpoint number.
 *
 * Returns +nil+ in any case, and raises an exception on failure.
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
      return INT2NUM(res);
    }
  }
  res = libusb_clear_halt (d->handle, NUM2INT(endpoint));
  if (res < 0)
    rb_raise (rb_eRuntimeError, "Failed to clear halt/stall condition: %s.", find_error_text (res));
  return INT2NUM(res);
}

/*
 * call-seq: device.resetDevice -> nil
 *
 * Reset device.
 *
 * Returns +nil+ in any case, and raises an exception on failure.
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
      return INT2NUM(res);
    }
  }
  res = libusb_reset_device (d->handle);
  if (res < 0)
    rb_raise (rb_eRuntimeError, "Failed to reset device: %s.", find_error_text (res));
  return INT2NUM(res);
}

/*
 * call-seq:
 *   device.kernelDriverActive?(interface) -> result
 *
 * Determine if a kernel driver is active on a given interface.
 *
 * - +interface+ is a +FixNum+ containing the interface number.
 *
 * On success, returns whether or not the device interface is claimed by a kernel driver (+true+ or +false+), otherwise raises an exception and returns the _libusb_ error code (+FixNum+).
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
      return INT2NUM(res);
    }
  }
  res = libusb_kernel_driver_active (d->handle, NUM2INT(interface));
  if (res < 0) {
    rb_raise (rb_eRuntimeError, "Failed to determine whether a kernel driver is active on interface: %s.", find_error_text (res));
    return INT2NUM(res);
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
 * Returns +nil+ in any case, and raises an exception on failure.
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
      return INT2NUM(res);
    }
  }
  res = libusb_detach_kernel_driver (d->handle, NUM2INT(interface));
  if (res < 0)
    rb_raise (rb_eRuntimeError, "Failed to detach kernel driver: %s.", find_error_text (res));
  return INT2NUM(res);
}

/*
 * call-seq:
 *   device.attachKernelDriver(interface) -> nil
 *
 * Re-attach a kernel driver from an interface.
 *
 * - +interface+ is a +FixNum+ containing the interface number.
 *
 * Returns +nil+ in any case, and raises an exception on failure.
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
      return INT2NUM(res);
    }
  }
  res = libusb_attach_kernel_driver (d->handle, NUM2INT(interface));
  if (res < 0)
    rb_raise (rb_eRuntimeError, "Failed to re-attach kernel driver: %s.", find_error_text (res));
  return INT2NUM(res);
}

/*
 * call-seq:
 *   device.getDeviceDescriptor -> descriptor
 *   device.deviceDescriptor -> descriptor
 *
 * Obtain the USB device descriptor for the device.
 *
 * On success, returns the USB descriptor of the device (+RibUSB::DeviceDescriptor+), otherwise raises an exception and returns the _libusb_ error code (+FixNum+).
 */
static VALUE cDevice_get_device_descriptor (VALUE self, VALUE interface)
{
  struct device_t *d;
  struct libusb_device_descriptor *desc;
  int res;

  desc = (struct libusb_device_descriptor *) malloc (sizeof (struct libusb_device_descriptor));
  if (!desc) {
    rb_raise (rb_eRuntimeError, "Failed to allocate memory for struct libusb_device_descriptor.");
    return Qnil;
  }

  Data_Get_Struct (self, struct device_t, d);
  res = libusb_get_device_descriptor (d->device, desc);
  if (res < 0)
    rb_raise (rb_eRuntimeError, "Failed to retrieve device descriptor: %s.", find_error_text (res));
  return cDeviceDescriptor_new (desc);
}

/*
 * call-seq:
 *   device.getStringDescriptorASCII(index) -> desc
 *   device.stringDescriptorASCII(index) -> desc
 *
 * - +index+ is a +FixNum+ specifying the index of the descriptor string.
 *
 * Retrieve an ASCII descriptor string from the device.
 *
 * On success, returns the ASCII descriptor string of given index (+String+), otherwise raises an exception and returns the _libusb_ error code (+FixNum+).
 */
static VALUE cDevice_get_string_descriptor_ascii (VALUE self, VALUE index)
{
  struct device_t *d;
  int res;
  char c[256];

  Data_Get_Struct (self, struct device_t, d);
  if (d->handle == NULL) {
    res = libusb_open (d->device, &(d->handle));
    if (res < 0) {
      rb_raise (rb_eRuntimeError, "Failed to open USB device: %s.", find_error_text (res));
      return INT2NUM(res);
    }
  }
  res = libusb_get_string_descriptor_ascii (d->handle, NUM2INT(index), c, sizeof (c));
  if (res < 0)
    rb_raise (rb_eRuntimeError, "Failed to retrieve descriptor string: %s.", find_error_text (res));
  return rb_str_new(c, res);
}

/*
 * call-seq:
 *   device.getStringDescriptor(index, langid) -> desc
 *   device.stringDescriptor(index, langid) -> desc
 *
 * - +index+ is a +FixNum+ specifying the index of the descriptor string.
 * - +langid+ is a +FixNum+ specifying the ID of the language to be retrieved
 *
 * Retrieve a descriptor string from the device.
 *
 * On success, returns the descriptor string of given index in given language (+String+), otherwise raises an exception and returns the _libusb_ error code (+FixNum+).
 */
static VALUE cDevice_get_string_descriptor (VALUE self, VALUE index, VALUE langid)
{
  struct device_t *d;
  int res;
  char c[256];

  Data_Get_Struct (self, struct device_t, d);
  if (d->handle == NULL) {
    res = libusb_open (d->device, &(d->handle));
    if (res < 0) {
      rb_raise (rb_eRuntimeError, "Failed to open USB device: %s.", find_error_text (res));
      return INT2NUM(res);
    }
  }
  res = libusb_get_string_descriptor (d->handle, NUM2INT(index), NUM2INT(langid), c, sizeof (c));
  if (res < 0)
    rb_raise (rb_eRuntimeError, "Failed to retrieve descriptor string: %s.", find_error_text (res));
  return rb_str_new(c, res);
}

/*
 * call-seq:
 *   device.controlTransfer(bmRequestType, bRequest, wValue, wIndex, data, timeout) -> count
 *
 * - +bmRequestType+ is a +FixNum+ specifying the 8-bit request type field of the setup packet (which also contains the direction bit)
 * - +bRequest+ is a +FixNum+ specifying the 8-bit request field of the setup packet
 * - +wValue+ is a +FixNum+ specifying the 16-bit value field of the setup packet
 * - +wIndex+ is a +FixNum+ specifying the 16-bit index field of the setup packet
 * - +data+ is a +String+ acting as a source for output transfers and as a buffer for input transfers; its size determines the number of bytes to be transferred (wLength)
 * - +timeout+ is a +FixNum+ specifying the timeout for this transfer in milliseconds
 *
 * Perform a synchronous (blocking) control transfer.
 *
 * On success, returns the number of data bytes transferred (+FixNum+), otherwise raises an exception and returns the _libusb_ error code (+FixNum+).
 */
static VALUE cDevice_controlTransfer (VALUE self, VALUE bmRequestType, VALUE bRequest, VALUE wValue, VALUE wIndex, VALUE data, VALUE timeout)
{
  struct device_t *d;
  int res;

  Data_Get_Struct (self, struct device_t, d);
  if (d->handle == NULL) {
    res = libusb_open (d->device, &(d->handle));
    if (res < 0) {
      rb_raise (rb_eRuntimeError, "Failed to open USB device: %s.", find_error_text (res));
      return INT2NUM(res);
    }
  }
  res = libusb_control_transfer (d->handle, NUM2INT(bmRequestType), NUM2INT(bRequest), NUM2INT(wValue), NUM2INT(wIndex), RSTRING(data)->ptr, RSTRING(data)->len, NUM2INT(timeout));
  if (res < 0)
    rb_raise (rb_eRuntimeError, "Synchronous control transfer failed: %s.", find_error_text (res));
  return INT2NUM(res);
}

/*
 * call-seq:
 *   device.bulkTransfer(endpoint, data, timeout) -> [ count, status ]
 *
 * - +endpoint+ is a +FixNum+ specifying the endpoint for the transfer (which also contains the direction bit)
 * - +data+ is a +String+ acting as a source for output transfers and as a buffer for input transfers; its size determines the number of bytes to be transferred
 * - +timeout+ is a +FixNum+ specifying the timeout for this transfer in milliseconds
 *
 * Perform a synchronous (blocking) bulk transfer.
 *
 * Returns an array of two <tt>FixNum</tt>s.
 * Regardless of any error, +count+ contains the actual number of bytes transferred. This is relevant as the transfer might have partially succeeded.
 * On success, +status+ contains <tt>0</tt>, otherwise an error is raised and +status+ contains the _libusb_ error code.
 */
static VALUE cDevice_bulkTransfer (VALUE self, VALUE endpoint, VALUE data, VALUE timeout)
{
  struct device_t *d;
  int res;
  int nxfer;
  VALUE array;

  Data_Get_Struct (self, struct device_t, d);
  if (d->handle == NULL) {
    res = libusb_open (d->device, &(d->handle));
    if (res < 0) {
      rb_raise (rb_eRuntimeError, "Failed to open USB device: %s.", find_error_text (res));
      return INT2NUM(res);
    }
  }
  res = libusb_bulk_transfer (d->handle, NUM2INT(endpoint), RSTRING(data)->ptr, RSTRING(data)->len, &nxfer, NUM2INT(timeout));
  if (res < 0) {
    rb_raise (rb_eRuntimeError, "Synchronous bulk transfer failed: %s.", find_error_text (res));
    return INT2NUM(res);
  }
  array = rb_ary_new2 (2);
  rb_ary_store (array, 0, INT2NUM(nxfer));
  rb_ary_store (array, 1, INT2NUM(res));
  return array;
}

/*
 * call-seq:
 *   device.interruptTransfer(endpoint, data, timeout) -> [ count, status ]
 *
 * - +endpoint+ is a +FixNum+ specifying the endpoint for the transfer (which also contains the direction bit)
 * - +data+ is a +String+ acting as a source for output transfers and as a buffer for input transfers; its size determines the number of bytes to be transferred
 * - +timeout+ is a +FixNum+ specifying the timeout for this transfer in milliseconds
 *
 * Perform a synchronous (blocking) interrupt transfer.
 *
 * Returns an array of two <tt>FixNum</tt>s.
 * Regardless of any error, +count+ contains the actual number of bytes transferred. This is relevant as the transfer might have partially succeeded.
 * On success, +status+ contains <tt>0</tt>, otherwise an error is raised and +status+ contains the _libusb_ error code.
 */
static VALUE cDevice_interruptTransfer (VALUE self, VALUE endpoint, VALUE data, VALUE timeout)
{
  struct device_t *d;
  int res;
  int nxfer;
  VALUE array;

  Data_Get_Struct (self, struct device_t, d);
  if (d->handle == NULL) {
    res = libusb_open (d->device, &(d->handle));
    if (res < 0) {
      rb_raise (rb_eRuntimeError, "Failed to open USB device: %s.", find_error_text (res));
      return INT2NUM(res);
    }
  }
  res = libusb_interrupt_transfer (d->handle, NUM2INT(endpoint), RSTRING(data)->ptr, RSTRING(data)->len, &nxfer, NUM2INT(timeout));
  if (res < 0) {
    rb_raise (rb_eRuntimeError, "Synchronous interrupt transfer failed: %s.", find_error_text (res));
    return INT2NUM(res);
  }
  array = rb_ary_new2 (2);
  rb_ary_store (array, 0, INT2NUM(nxfer));
  rb_ary_store (array, 1, INT2NUM(res));
  return array;
}



/******************************************************
 * RibUSB::DeviceDescriptor method definitions        *
 ******************************************************/

static VALUE cDeviceDescriptor_new (struct libusb_device_descriptor *descriptor)
{
  struct device_descriptor_t *d;
  VALUE object;

  d = (struct device_descriptor_t *) malloc (sizeof (struct device_descriptor_t));
  if (!d) {
    rb_raise (rb_eRuntimeError, "Failed to allocate memory for RibUSB::DeviceDescriptor object.");
    return Qnil;
  }
  d->descriptor = descriptor;
  object = Data_Wrap_Struct (rb_cDeviceDescriptor, NULL, free, d);
  rb_obj_call_init (object, 0, 0);
  return object;
}

/*
 * call-seq:
 *   descriptor.bLength -> bLength
 *
 * Get the size in bytes of the descriptor.
 *
 * Returns a +FixNum+ and never raises an exception.
 */
static VALUE cDeviceDescriptor_bLength (VALUE self)
{
  struct device_descriptor_t *d;

  Data_Get_Struct (self, struct device_descriptor_t, d);
  return INT2NUM(d->descriptor->bLength);
}

/*
 * call-seq:
 *   descriptor.bDescriptorType -> bDescriptorType
 *
 * Get the type of the descriptor.
 *
 * Returns a +FixNum+ and never raises an exception.
 */
static VALUE cDeviceDescriptor_bDescriptorType (VALUE self)
{
  struct device_descriptor_t *d;

  Data_Get_Struct (self, struct device_descriptor_t, d);
  return INT2NUM(d->descriptor->bDescriptorType);
}

/*
 * call-seq:
 *   descriptor.bcdUSB -> bcdUSB
 *
 * Get the USB specification release number in binary-coded decimal.
 *
 * Returns a +FixNum+ and never raises an exception.
 */
static VALUE cDeviceDescriptor_bcdUSB (VALUE self)
{
  struct device_descriptor_t *d;

  Data_Get_Struct (self, struct device_descriptor_t, d);
  return INT2NUM(d->descriptor->bcdUSB);
}

/*
 * call-seq:
 *   descriptor.bDeviceClass -> bDeviceClass
 *
 * Get the USB class code.
 *
 * Returns a +FixNum+ and never raises an exception.
 */
static VALUE cDeviceDescriptor_bDeviceClass (VALUE self)
{
  struct device_descriptor_t *d;

  Data_Get_Struct (self, struct device_descriptor_t, d);
  return INT2NUM(d->descriptor->bDeviceClass);
}

/*
 * call-seq:
 *   descriptor.bDeviceSubClass -> bDeviceSubClass
 *
 * Get the USB subclass code.
 *
 * Returns a +FixNum+ and never raises an exception.
 */
static VALUE cDeviceDescriptor_bDeviceSubClass (VALUE self)
{
  struct device_descriptor_t *d;

  Data_Get_Struct (self, struct device_descriptor_t, d);
  return INT2NUM(d->descriptor->bDeviceSubClass);
}

/*
 * call-seq:
 *   descriptor.bDeviceProtocol -> bDeviceProtocol
 *
 * Get the USB protocol code.
 *
 * Returns a +FixNum+ and never raises an exception.
 */
static VALUE cDeviceDescriptor_bDeviceProtocol (VALUE self)
{
  struct device_descriptor_t *d;

  Data_Get_Struct (self, struct device_descriptor_t, d);
  return INT2NUM(d->descriptor->bDeviceProtocol);
}

/*
 * call-seq:
 *   descriptor.bMaxPacketSize0 -> bMaxPacketSize0
 *
 * Get the maximum packet size for endpoint 0.
 *
 * Returns a +FixNum+ and never raises an exception.
 */
static VALUE cDeviceDescriptor_bMaxPacketSize0 (VALUE self)
{
  struct device_descriptor_t *d;

  Data_Get_Struct (self, struct device_descriptor_t, d);
  return INT2NUM(d->descriptor->bMaxPacketSize0);
}

/*
 * call-seq:
 *   descriptor.idVendor -> idVendor
 *
 * Get the vendor ID.
 *
 * Returns a +FixNum+ and never raises an exception.
 */
static VALUE cDeviceDescriptor_idVendor (VALUE self)
{
  struct device_descriptor_t *d;

  Data_Get_Struct (self, struct device_descriptor_t, d);
  return INT2NUM(d->descriptor->idVendor);
}

/*
 * call-seq:
 *   descriptor.idProduct -> idProduct
 *
 * Get the product ID.
 *
 * Returns a +FixNum+ and never raises an exception.
 */
static VALUE cDeviceDescriptor_idProduct (VALUE self)
{
  struct device_descriptor_t *d;

  Data_Get_Struct (self, struct device_descriptor_t, d);
  return INT2NUM(d->descriptor->idProduct);
}

/*
 * call-seq:
 *   descriptor.bcdDevice -> bcdDevice
 *
 * Get the device release number in binary-coded decimal.
 *
 * Returns a +FixNum+ and never raises an exception.
 */
static VALUE cDeviceDescriptor_bcdDevice (VALUE self)
{
  struct device_descriptor_t *d;

  Data_Get_Struct (self, struct device_descriptor_t, d);
  return INT2NUM(d->descriptor->bcdDevice);
}

/*
 * call-seq:
 *   descriptor.iManufacturer -> iManufacturer
 *
 * Get the index of the manufacturer string.
 *
 * Returns a +FixNum+ and never raises an exception.
 */
static VALUE cDeviceDescriptor_iManufacturer (VALUE self)
{
  struct device_descriptor_t *d;

  Data_Get_Struct (self, struct device_descriptor_t, d);
  return INT2NUM(d->descriptor->iManufacturer);
}

/*
 * call-seq:
 *   descriptor.iProduct -> iProduct
 *
 * Get the index of the product string.
 *
 * Returns a +FixNum+ and never raises an exception.
 */
static VALUE cDeviceDescriptor_iProduct (VALUE self)
{
  struct device_descriptor_t *d;

  Data_Get_Struct (self, struct device_descriptor_t, d);
  return INT2NUM(d->descriptor->iProduct);
}

/*
 * call-seq:
 *   descriptor.iSerialNumber -> iSerialNumber
 *
 * Get the index of the serial number string.
 *
 * Returns a +FixNum+ and never raises an exception.
 */
static VALUE cDeviceDescriptor_iSerialNumber (VALUE self)
{
  struct device_descriptor_t *d;

  Data_Get_Struct (self, struct device_descriptor_t, d);
  return INT2NUM(d->descriptor->iSerialNumber);
}

/*
 * call-seq:
 *   descriptor.bNumConfigurations -> bNumConfigurations
 *
 * Get the number of configurations of the device.
 *
 * Returns a +FixNum+ and never raises an exception.
 */
static VALUE cDeviceDescriptor_bNumConfigurations (VALUE self)
{
  struct device_descriptor_t *d;

  Data_Get_Struct (self, struct device_descriptor_t, d);
  return INT2NUM(d->descriptor->bNumConfigurations);
}



/******************************************************
 * RibUSB::ConfigDescriptor method definitions        *
 ******************************************************/

void cConfigDescriptor_free (struct config_descriptor_t *c)
{
  libusb_free_config_descriptor (c->descriptor);

  free (c);
}

static VALUE cConfigDescriptor_new (struct libusb_config_descriptor *descriptor)
{
  struct config_descriptor_t *d;
  VALUE object;

  d = (struct config_descriptor_t *) malloc (sizeof (struct config_descriptor_t));
  if (!d) {
    rb_raise (rb_eRuntimeError, "Failed to allocate memory for RibUSB::ConfigDescriptor object.");
    return Qnil;
  }
  d->descriptor = descriptor;
  object = Data_Wrap_Struct (rb_cConfigDescriptor, NULL, cConfigDescriptor_free, d);
  rb_obj_call_init (object, 0, 0);
  return object;
}

/*
 * call-seq:
 *   descriptor.bLength -> bLength
 *
 * Get the size in bytes of the descriptor.
 *
 * Returns a +FixNum+ and never raises an exception.
 */
static VALUE cConfigDescriptor_bLength (VALUE self)
{
  struct config_descriptor_t *d;

  Data_Get_Struct (self, struct config_descriptor_t, d);
  return INT2NUM(d->descriptor->bLength);
}

/*
 * call-seq:
 *   descriptor.bDescriptorType -> bDescriptorType
 *
 * Get the type of the descriptor.
 *
 * Returns a +FixNum+ and never raises an exception.
 */
static VALUE cConfigDescriptor_bDescriptorType (VALUE self)
{
  struct config_descriptor_t *d;

  Data_Get_Struct (self, struct config_descriptor_t, d);
  return INT2NUM(d->descriptor->bDescriptorType);
}

/*
 * call-seq:
 *   descriptor.wTotalLength -> wTotalLength
 *
 * Get the total length of the data of this configuration.
 *
 * Returns a +FixNum+ and never raises an exception.
 */
static VALUE cConfigDescriptor_wTotalLength (VALUE self)
{
  struct config_descriptor_t *d;

  Data_Get_Struct (self, struct config_descriptor_t, d);
  return INT2NUM(d->descriptor->wTotalLength);
}

/*
 * call-seq:
 *   descriptor.bNumInterfaces -> bNumInterfaces
 *
 * Get the number of interfaces available in this configuration.
 *
 * Returns a +FixNum+ and never raises an exception.
 */
static VALUE cConfigDescriptor_bNumInterfaces (VALUE self)
{
  struct config_descriptor_t *d;

  Data_Get_Struct (self, struct config_descriptor_t, d);
  return INT2NUM(d->descriptor->bNumInterfaces);
}

/*
 * call-seq:
 *   descriptor.bConfigurationValue -> bConfigurationValue
 *
 * Get the configuration number.
 *
 * Returns a +FixNum+ and never raises an exception.
 */
static VALUE cConfigDescriptor_bConfigurationValue (VALUE self)
{
  struct config_descriptor_t *d;

  Data_Get_Struct (self, struct config_descriptor_t, d);
  return INT2NUM(d->descriptor->bConfigurationValue);
}

/*
 * call-seq:
 *   descriptor.iConfiguration -> iConfiguration
 *
 * Get the index of the configuration string.
 *
 * Returns a +FixNum+ and never raises an exception.
 */
static VALUE cConfigDescriptor_iConfiguration (VALUE self)
{
  struct config_descriptor_t *d;

  Data_Get_Struct (self, struct config_descriptor_t, d);
  return INT2NUM(d->descriptor->iConfiguration);
}

/*
 * call-seq:
 *   descriptor.bmAttributes -> bmAttributes
 *
 * Get the configuration characteristics.
 *
 * Returns a +FixNum+ and never raises an exception.
 */
static VALUE cConfigDescriptor_bmAttributes (VALUE self)
{
  struct config_descriptor_t *d;

  Data_Get_Struct (self, struct config_descriptor_t, d);
  return INT2NUM(d->descriptor->bmAttributes);
}

/*
 * call-seq:
 *   descriptor.maxPower -> maxPower
 *
 * Get the maximum current drawn by the device in this configuration, in units of 2mA.
 *
 * Returns a +FixNum+ and never raises an exception.
 */
static VALUE cConfigDescriptor_maxPower (VALUE self)
{
  struct config_descriptor_t *d;

  Data_Get_Struct (self, struct config_descriptor_t, d);
  return INT2NUM(d->descriptor->MaxPower);
}

/*
 * call-seq:
 *   descriptor.interfaceList -> interfaceList
 *
 * Retrieve the list of interfaces in this configuration.
 *
 * Returns an array of +RibUSB::Interface+ and never raises an exception.
 */
static VALUE cConfigDescriptor_interfaceList (VALUE self)
{
  struct config_descriptor_t *d;
  VALUE array;
  int n_array, i;

  Data_Get_Struct (self, struct config_descriptor_t, d);

  n_array = d->descriptor->bNumInterfaces;
  array = rb_ary_new2 (n_array);

  for (i = 0; i < n_array; i ++)
    rb_ary_store (array, i, cInterface_new (&(((struct libusb_interface *)d->descriptor->interface)[i])));

  return array;
}

/*
 * call-seq:
 *   descriptor.extra -> extra
 *
 * Get the extra descriptors defined by this configuration, as a string.
 *
 * Returns a +String+ and never raises an exception.
 */
static VALUE cConfigDescriptor_extra (VALUE self)
{
  struct config_descriptor_t *d;

  Data_Get_Struct (self, struct config_descriptor_t, d);
  return rb_str_new(d->descriptor->extra, d->descriptor->extra_length);
}



/******************************************************
 * RibUSB::Interface method definitions               *
 ******************************************************/

static VALUE cInterface_new (struct libusb_interface *interface)
{
  struct interface_t *i;
  VALUE object;

  i = (struct interface_t *) malloc (sizeof (struct interface_t));
  if (!i) {
    rb_raise (rb_eRuntimeError, "Failed to allocate memory for RibUSB::Interface object.");
    return Qnil;
  }
  i->interface = interface;
  object = Data_Wrap_Struct (rb_cInterface, NULL, free, i);
  rb_obj_call_init (object, 0, 0);
  return object;
}

/*
 * call-seq:
 *   interface.altSettingList -> altSettingList
 *
 * Retrieve the list of interface descriptors.
 *
 * Returns an array of +RibUSB::Interface+ and never raises an exception.
 */
static VALUE cInterface_altSettingList (VALUE self)
{
  struct interface_t *d;
  VALUE array;
  int n_array, i;

  Data_Get_Struct (self, struct interface_t, d);

  n_array = d->interface->num_altsetting;
  array = rb_ary_new2 (n_array);

  for (i = 0; i < n_array; i ++)
    rb_ary_store (array, i, cInterfaceDescriptor_new (&(((struct libusb_interface_descriptor *)d->interface->altsetting)[i])));

  return array;
}



/******************************************************
 * RibUSB::InterfaceDescriptor method definitions     *
 ******************************************************/

static VALUE cInterfaceDescriptor_new (struct libusb_interface_descriptor *descriptor)
{
  struct interface_descriptor_t *d;
  VALUE object;

  d = (struct interface_descriptor_t *) malloc (sizeof (struct interface_descriptor_t));
  if (!d) {
    rb_raise (rb_eRuntimeError, "Failed to allocate memory for RibUSB::InterfaceDescriptor object.");
    return Qnil;
  }
  d->descriptor = descriptor;
  object = Data_Wrap_Struct (rb_cInterfaceDescriptor, NULL, free, d);
  rb_obj_call_init (object, 0, 0);
  return object;
}

/*
 * call-seq:
 *   descriptor.bLength -> bLength
 *
 * Get the size in bytes of the descriptor.
 *
 * Returns a +FixNum+ and never raises an exception.
 */
static VALUE cInterfaceDescriptor_bLength (VALUE self)
{
  struct interface_descriptor_t *d;

  Data_Get_Struct (self, struct interface_descriptor_t, d);
  return INT2NUM(d->descriptor->bLength);
}

/*
 * call-seq:
 *   descriptor.bDescriptorType -> bDescriptorType
 *
 * Get the type of the descriptor.
 *
 * Returns a +FixNum+ and never raises an exception.
 */
static VALUE cInterfaceDescriptor_bDescriptorType (VALUE self)
{
  struct interface_descriptor_t *d;

  Data_Get_Struct (self, struct interface_descriptor_t, d);
  return INT2NUM(d->descriptor->bDescriptorType);
}

/*
 * call-seq:
 *   descriptor.bInterfaceNumber -> bInterfaceNumber
 *
 * Get the interface number.
 *
 * Returns a +FixNum+ and never raises an exception.
 */
static VALUE cInterfaceDescriptor_bInterfaceNumber (VALUE self)
{
  struct interface_descriptor_t *d;

  Data_Get_Struct (self, struct interface_descriptor_t, d);
  return INT2NUM(d->descriptor->bInterfaceNumber);
}

/*
 * call-seq:
 *   descriptor.bAlternateSetting -> bAlternateSetting
 *
 * Get the number of the active alternate setting.
 *
 * Returns a +FixNum+ and never raises an exception.
 */
static VALUE cInterfaceDescriptor_bAlternateSetting (VALUE self)
{
  struct interface_descriptor_t *d;

  Data_Get_Struct (self, struct interface_descriptor_t, d);
  return INT2NUM(d->descriptor->bAlternateSetting);
}

/*
 * call-seq:
 *   descriptor.bNumEndpoints -> bNumEndpoints
 *
 * Get the number of endpoints available in this interface.
 *
 * Returns a +FixNum+ and never raises an exception.
 */
static VALUE cInterfaceDescriptor_bNumEndpoints (VALUE self)
{
  struct interface_descriptor_t *d;

  Data_Get_Struct (self, struct interface_descriptor_t, d);
  return INT2NUM(d->descriptor->bNumEndpoints);
}

/*
 * call-seq:
 *   descriptor.bInterfaceClass -> bInterfaceClass
 *
 * Get the interface class code.
 *
 * Returns a +FixNum+ and never raises an exception.
 */
static VALUE cInterfaceDescriptor_bInterfaceClass (VALUE self)
{
  struct interface_descriptor_t *d;

  Data_Get_Struct (self, struct interface_descriptor_t, d);
  return INT2NUM(d->descriptor->bInterfaceClass);
}

/*
 * call-seq:
 *   descriptor.bInterfaceSubClass -> bInterfaceSubClass
 *
 * Get the interface subclass code.
 *
 * Returns a +FixNum+ and never raises an exception.
 */
static VALUE cInterfaceDescriptor_bInterfaceSubClass (VALUE self)
{
  struct interface_descriptor_t *d;

  Data_Get_Struct (self, struct interface_descriptor_t, d);
  return INT2NUM(d->descriptor->bInterfaceSubClass);
}

/*
 * call-seq:
 *   descriptor.bInterfaceProtocol -> bInterfaceProtocol
 *
 * Get the interface protocol code.
 *
 * Returns a +FixNum+ and never raises an exception.
 */
static VALUE cInterfaceDescriptor_bInterfaceProtocol (VALUE self)
{
  struct interface_descriptor_t *d;

  Data_Get_Struct (self, struct interface_descriptor_t, d);
  return INT2NUM(d->descriptor->bInterfaceProtocol);
}

/*
 * call-seq:
 *   descriptor.iInterface -> iInterface
 *
 * Get the index of interface string.
 *
 * Returns a +FixNum+ and never raises an exception.
 */
static VALUE cInterfaceDescriptor_iInterface (VALUE self)
{
  struct interface_descriptor_t *d;

  Data_Get_Struct (self, struct interface_descriptor_t, d);
  return INT2NUM(d->descriptor->iInterface);
}

/*
 * call-seq:
 *   descriptor.endpointList -> endpointList
 *
 * Retrieve the list of endpoints in this interface.
 *
 * Returns an array of +RibUSB::Endpoint+ and never raises an exception.
 */
static VALUE cInterfaceDescriptor_endpointList (VALUE self)
{
  struct interface_descriptor_t *d;
  VALUE array;
  int n_array, i;

  Data_Get_Struct (self, struct interface_descriptor_t, d);

  n_array = d->descriptor->bNumEndpoints;
  array = rb_ary_new2 (n_array);

  for (i = 0; i < n_array; i ++)
    rb_ary_store (array, i, cEndpointDescriptor_new (&(((struct libusb_endpoint_descriptor *)d->descriptor->endpoint)[i])));

  return array;
}

/*
 * call-seq:
 *   descriptor.extra -> extra
 *
 * Get the extra descriptors defined by this interface, as a string.
 *
 * Returns a +String+ and never raises an exception.
 */
static VALUE cInterfaceDescriptor_extra (VALUE self)
{
  struct interface_descriptor_t *d;

  Data_Get_Struct (self, struct interface_descriptor_t, d);
  return rb_str_new(d->descriptor->extra, d->descriptor->extra_length);
}



/******************************************************
 * RibUSB::EndpointDescriptor method definitions      *
 ******************************************************/

static VALUE cEndpointDescriptor_new (struct libusb_endpoint_descriptor *descriptor)
{
  struct endpoint_descriptor_t *d;
  VALUE object;

  d = (struct endpoint_descriptor_t *) malloc (sizeof (struct endpoint_descriptor_t));
  if (!d) {
    rb_raise (rb_eRuntimeError, "Failed to allocate memory for RibUSB::EndpointDescriptor object.");
    return Qnil;
  }
  d->descriptor = descriptor;
  object = Data_Wrap_Struct (rb_cEndpointDescriptor, NULL, free, d);
  rb_obj_call_init (object, 0, 0);
  return object;
}

/*
 * call-seq:
 *   descriptor.bLength -> bLength
 *
 * Get the size in bytes of the descriptor.
 *
 * Returns a +FixNum+ and never raises an exception.
 */
static VALUE cEndpointDescriptor_bLength (VALUE self)
{
  struct endpoint_descriptor_t *d;

  Data_Get_Struct (self, struct endpoint_descriptor_t, d);
  return INT2NUM(d->descriptor->bLength);
}

/*
 * call-seq:
 *   descriptor.bDescriptorType -> bDescriptorType
 *
 * Get the type of the descriptor.
 *
 * Returns a +FixNum+ and never raises an exception.
 */
static VALUE cEndpointDescriptor_bDescriptorType (VALUE self)
{
  struct endpoint_descriptor_t *d;

  Data_Get_Struct (self, struct endpoint_descriptor_t, d);
  return INT2NUM(d->descriptor->bDescriptorType);
}

/*
 * call-seq:
 *   descriptor.bEndpointAddress -> bEndpointAddress
 *
 * Get the endpoint address.
 *
 * Returns a +FixNum+ and never raises an exception.
 */
static VALUE cEndpointDescriptor_bEndpointAddress (VALUE self)
{
  struct endpoint_descriptor_t *d;

  Data_Get_Struct (self, struct endpoint_descriptor_t, d);
  return INT2NUM(d->descriptor->bEndpointAddress);
}

/*
 * call-seq:
 *   descriptor.bmAttributes -> bmAttributes
 *
 * Get the endpoint attributes.
 *
 * Returns a +FixNum+ and never raises an exception.
 */
static VALUE cEndpointDescriptor_bmAttributes (VALUE self)
{
  struct endpoint_descriptor_t *d;

  Data_Get_Struct (self, struct endpoint_descriptor_t, d);
  return INT2NUM(d->descriptor->bmAttributes);
}

/*
 * call-seq:
 *   descriptor.wMaxPacketSize -> wMaxPacketSize
 *
 * Get the maximum packet size of the endpoint.
 *
 * Returns a +FixNum+ and never raises an exception.
 */
static VALUE cEndpointDescriptor_wMaxPacketSize (VALUE self)
{
  struct endpoint_descriptor_t *d;

  Data_Get_Struct (self, struct endpoint_descriptor_t, d);
  return INT2NUM(d->descriptor->wMaxPacketSize);
}

/*
 * call-seq:
 *   descriptor.bInterval -> bInterval
 *
 * Get the polling interval for data transfers on this endpoint.
 *
 * Returns a +FixNum+ and never raises an exception.
 */
static VALUE cEndpointDescriptor_bInterval (VALUE self)
{
  struct endpoint_descriptor_t *d;

  Data_Get_Struct (self, struct endpoint_descriptor_t, d);
  return INT2NUM(d->descriptor->bInterval);
}

/*
 * call-seq:
 *   descriptor.bRefresh -> bRefresh
 *
 * Get the rate of synchronization feedback for audio devices.
 *
 * Returns a +FixNum+ and never raises an exception.
 */
static VALUE cEndpointDescriptor_bRefresh (VALUE self)
{
  struct endpoint_descriptor_t *d;

  Data_Get_Struct (self, struct endpoint_descriptor_t, d);
  return INT2NUM(d->descriptor->bRefresh);
}

/*
 * call-seq:
 *   descriptor.bSynchAddress -> bSynchAddress
 *
 * Get the address of the synchronization endpoint for audio devices.
 *
 * Returns a +FixNum+ and never raises an exception.
 */
static VALUE cEndpointDescriptor_bSynchAddress (VALUE self)
{
  struct endpoint_descriptor_t *d;

  Data_Get_Struct (self, struct endpoint_descriptor_t, d);
  return INT2NUM(d->descriptor->bSynchAddress);
}

/*
 * call-seq:
 *   descriptor.extra -> extra
 *
 * Get the extra descriptors defined by this endpoint, as a string.
 *
 * Returns a +String+ and never raises an exception.
 */
static VALUE cEndpointDescriptor_extra (VALUE self)
{
  struct endpoint_descriptor_t *d;

  Data_Get_Struct (self, struct endpoint_descriptor_t, d);
  return rb_str_new(d->descriptor->extra, d->descriptor->extra_length);
}



/******************************************************
 * RibUSB::Transfer method definitions                *
 ******************************************************/

void cTransfer_free (struct transfer_t *t)
{
  libusb_free_transfer (t->transfer);

  free (t);
}

/*
 * call-seq:
 *   RibUSB::Transfer.new(iso_packets) -> transfer
 *
 * - +iso_packets+ is a +FixNum+ specifying the number of isochronous packet descriptors
 *
 * Create an instance of RibUSB::Transfer.
 *
 * Effectively creates a _libusb_ transfer (the transfer itself being stored in an opaque structure). The memory associated with the transfer is automatically freed on garbage collection when possible.
 *
 * If successful, returns the transfer object, otherwise raises an exception and returns +nil+.
 */
static VALUE cTransfer_new (VALUE self, VALUE iso_packets)
{
  struct transfer_t *t;
  VALUE object;

  t = (struct transfer_t *) malloc (sizeof (struct transfer_t));
  if (!t) {
    rb_raise (rb_eRuntimeError, "Failed to allocate memory for RibUSB::Transfer object.");
    return Qnil;
  }
  t->transfer = libusb_alloc_transfer (iso_packets);
  t->buffer = NULL;
  if (!(t->transfer)) {
    rb_raise (rb_eRuntimeError, "Failed to allocate libusb transfer.");
    free (t);
    return Qnil;
  }
  object = Data_Wrap_Struct (rb_cTransfer, NULL, cTransfer_free, t);
  rb_obj_call_init (object, 0, 0);
  return object;
}

/*
 * call-seq:
 *   transfer.submit -> result
 *
 * Asynchronously submit a previously defined transfer.
 *
 * If successful, returns +nil+, otherwise raises an exception and returns the _libusb_ error code (+FixNum+).
 */
static VALUE cTransfer_submit (VALUE self)
{
  struct transfer_t *t;
  int res;

  Data_Get_Struct (self, struct transfer_t, t);
  res = libusb_submit_transfer (t->transfer);
  if (res < 0) {
    rb_raise (rb_eRuntimeError, "Failed to submit asynchronous transfer: %s.", find_error_text (res));
    return INT2NUM(res);
  }
  return Qnil;
}

/*
 * call-seq:
 *   transfer.cancel -> result
 *
 * Asynchronously cancel a previously submitted transfer.
 *
 * If successful, returns +nil+, otherwise raises an exception and returns the _libusb_ error code (+FixNum+).
 */
static VALUE cTransfer_cancel (VALUE self)
{
  struct transfer_t *t;
  int res;

  Data_Get_Struct (self, struct transfer_t, t);
  res = libusb_cancel_transfer (t->transfer);
  if (res < 0) {
    rb_raise (rb_eRuntimeError, "Failed to cancel asynchronous transfer: %s.", find_error_text (res));
    return INT2NUM(res);
  }
  return Qnil;
}

/*
 * call-seq:
 *   transfer.fillControlTransfer(device, bmRequestType, bRequest, wValue, wIndex, data, timeout) {} -> nil
 *
 * - +device+ is the +RibUSB::Device+ the transfer is intended for
 * - +bmRequestType+ is a +FixNum+ specifying the 8-bit request type field of the setup packet (which also contains the direction bit)
 * - +bRequest+ is a +FixNum+ specifying the 8-bit request field of the setup packet
 * - +wValue+ is a +FixNum+ specifying the 16-bit value field of the setup packet
 * - +wIndex+ is a +FixNum+ specifying the 16-bit index field of the setup packet
 * - +data+ is a +String+ acting as a source for output transfers and as a buffer for input transfers; its size determines the number of bytes to be transferred (wLength)
 * - +timeout+ is a +FixNum+ specifying the timeout for this transfer in milliseconds
 *
 * Populate the entries required for a control transfer.
 *
 * Returns +nil+ in any case, and raises an exception on failure.
 */
static VALUE cTransfer_fillControlTransfer (VALUE self, VALUE device, VALUE bmRequestType, VALUE bRequest, VALUE wValue, VALUE wIndex, VALUE data, VALUE timeout)
{
  struct transfer_t *t;
  struct device_t *d;
  int res;

  Data_Get_Struct (self, struct transfer_t, t);
  Data_Get_Struct (device, struct device_t, d);
  t->buffer = (struct transfer_t *) realloc (t->buffer, 8 + RSTRING(data)->len);
  if (!(t->buffer)) {
    rb_raise (rb_eRuntimeError, "Failed to allocate memory for control transfer buffer.");
    return Qnil;
  }
  memcpy (t->buffer + 8, RSTRING(data)->ptr, RSTRING(data)->len);

  libusb_fill_control_setup (t->buffer, NUM2INT(bmRequestType), NUM2INT(bRequest), NUM2INT(wValue), NUM2INT(wIndex), RSTRING(data)->len);
  libusb_fill_control_transfer (t->transfer, d->handle, t->buffer, NULL, NULL, NUM2INT(timeout)); /* XXX callback */
  return Qnil;
}



/******************************************************
 * RibUSB -- an interface to _libusb_, API version 1.0
 ******************************************************/
void Init_ribusb()
{
  rb_mRibUSB = rb_define_module ("RibUSB");

  rb_define_singleton_method (rb_mRibUSB, "findError", mRibUSB_findError, 1);

  /* RibUSB::Bus -- a class for _libusb_ bus-handling sessions */
  rb_cBus = rb_define_class_under (rb_mRibUSB, "Bus", rb_cObject);
  rb_define_singleton_method (rb_cBus, "new", cBus_new, 0);
  rb_define_method (rb_cBus, "setDebug", cBus_setDebug, 1);
  rb_define_alias (rb_cBus, "debug=", "setDebug");
  rb_define_method (rb_cBus, "getDeviceList", cBus_getDeviceList, 0);
  rb_define_alias (rb_cBus, "deviceList", "getDeviceList");

  /* RibUSB::Device -- a class for individual USB devices accessed through _libusb_ */
  rb_cDevice = rb_define_class_under (rb_mRibUSB, "Device", rb_cObject);
  rb_define_method (rb_cDevice, "getBusNumber", cDevice_getBusNumber, 0);
  rb_define_alias (rb_cDevice, "busNumber", "getBusNumber");
  rb_define_method (rb_cDevice, "getDeviceAddress", cDevice_getDeviceAddress, 0);
  rb_define_alias (rb_cDevice, "deviceAddress", "getDeviceAddress");
  rb_define_method (rb_cDevice, "getMaxPacketSize", cDevice_getMaxPacketSize, 1);
  rb_define_alias (rb_cDevice, "maxPacketSize", "getMaxPacketSize");
  rb_define_method (rb_cDevice, "getConfiguration", cDevice_getConfiguration, 0);
  rb_define_alias (rb_cDevice, "configuration", "getConfiguration");
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
  rb_define_method (rb_cDevice, "getDeviceDescriptor", cDevice_get_device_descriptor, 0);
  rb_define_alias (rb_cDevice, "deviceDescriptor", "getDeviceDescriptor");
  rb_define_method (rb_cDevice, "getStringDescriptorASCII", cDevice_get_string_descriptor_ascii, 1);
  rb_define_alias (rb_cDevice, "stringDescriptorASCII", "getStringDescriptorASCII");
  rb_define_method (rb_cDevice, "getStringDescriptor", cDevice_get_string_descriptor, 2);
  rb_define_alias (rb_cDevice, "stringDescriptor", "getStringDescriptor");
  rb_define_method (rb_cDevice, "controlTransfer", cDevice_controlTransfer, 6);
  rb_define_method (rb_cDevice, "bulkTransfer", cDevice_bulkTransfer, 3);
  rb_define_method (rb_cDevice, "interruptTransfer", cDevice_interruptTransfer, 3);

  /* RibUSB::DeviceDescriptor -- a class for USB device descriptors */
  rb_cDeviceDescriptor = rb_define_class_under (rb_mRibUSB, "DeviceDescriptor", rb_cObject);
  rb_define_method (rb_cDeviceDescriptor, "bLength", cDeviceDescriptor_bLength, 0);
  rb_define_method (rb_cDeviceDescriptor, "bDescriptorType", cDeviceDescriptor_bDescriptorType, 0);
  rb_define_method (rb_cDeviceDescriptor, "bcdUSB", cDeviceDescriptor_bcdUSB, 0);
  rb_define_method (rb_cDeviceDescriptor, "bDeviceClass", cDeviceDescriptor_bDeviceClass, 0);
  rb_define_method (rb_cDeviceDescriptor, "bDeviceSubClass", cDeviceDescriptor_bDeviceSubClass, 0);
  rb_define_method (rb_cDeviceDescriptor, "bDeviceProtocol", cDeviceDescriptor_bDeviceProtocol, 0);
  rb_define_method (rb_cDeviceDescriptor, "bMaxPacketSize0", cDeviceDescriptor_bMaxPacketSize0, 0);
  rb_define_method (rb_cDeviceDescriptor, "idVendor", cDeviceDescriptor_idVendor, 0);
  rb_define_method (rb_cDeviceDescriptor, "idProduct", cDeviceDescriptor_idProduct, 0);
  rb_define_method (rb_cDeviceDescriptor, "bcdDevice", cDeviceDescriptor_bcdDevice, 0);
  rb_define_method (rb_cDeviceDescriptor, "iManufacturer", cDeviceDescriptor_iManufacturer, 0);
  rb_define_method (rb_cDeviceDescriptor, "iProduct", cDeviceDescriptor_iProduct, 0);
  rb_define_method (rb_cDeviceDescriptor, "iSerialNumber", cDeviceDescriptor_iSerialNumber, 0);
  rb_define_method (rb_cDeviceDescriptor, "bNumConfigurations", cDeviceDescriptor_bNumConfigurations, 0);

  /* RibUSB::ConfigDescriptor -- a class for USB config descriptors */
  rb_cConfigDescriptor = rb_define_class_under (rb_mRibUSB, "ConfigDescriptor", rb_cObject);
  rb_define_method (rb_cConfigDescriptor, "bLength", cConfigDescriptor_bLength, 0);
  rb_define_method (rb_cConfigDescriptor, "bDescriptorType", cConfigDescriptor_bDescriptorType, 0);
  rb_define_method (rb_cConfigDescriptor, "wTotalLength", cConfigDescriptor_wTotalLength, 0);
  rb_define_method (rb_cConfigDescriptor, "bNumInterfaces", cConfigDescriptor_bNumInterfaces, 0);
  rb_define_method (rb_cConfigDescriptor, "bConfigurationValue", cConfigDescriptor_bConfigurationValue, 0);
  rb_define_method (rb_cConfigDescriptor, "iConfiguration", cConfigDescriptor_iConfiguration, 0);
  rb_define_method (rb_cConfigDescriptor, "bmAttributes", cConfigDescriptor_bmAttributes, 0);
  rb_define_method (rb_cConfigDescriptor, "maxPower", cConfigDescriptor_maxPower, 0);
  rb_define_method (rb_cConfigDescriptor, "interfaceList", cConfigDescriptor_interfaceList, 0);
  rb_define_method (rb_cConfigDescriptor, "extra", cConfigDescriptor_extra, 0);

  /* RibUSB::Interface -- a class for USB interfaces */
  rb_cInterface = rb_define_class_under (rb_mRibUSB, "Interface", rb_cObject);
  rb_define_method (rb_cInterface, "altSettingList", cInterface_altSettingList, 0);

  /* RibUSB::InterfaceDescriptor -- a class for USB interface descriptors */
  rb_cInterfaceDescriptor = rb_define_class_under (rb_mRibUSB, "InterfaceDescriptor", rb_cObject);
  rb_define_method (rb_cInterfaceDescriptor, "bLength", cInterfaceDescriptor_bLength, 0);
  rb_define_method (rb_cInterfaceDescriptor, "bDescriptorType", cInterfaceDescriptor_bDescriptorType, 0);
  rb_define_method (rb_cInterfaceDescriptor, "bInterfaceNumber", cInterfaceDescriptor_bInterfaceNumber, 0);
  rb_define_method (rb_cInterfaceDescriptor, "bAlternateSetting", cInterfaceDescriptor_bAlternateSetting, 0);
  rb_define_method (rb_cInterfaceDescriptor, "bNumEndpoints", cInterfaceDescriptor_bNumEndpoints, 0);
  rb_define_method (rb_cInterfaceDescriptor, "bInterfaceClass", cInterfaceDescriptor_bInterfaceClass, 0);
  rb_define_method (rb_cInterfaceDescriptor, "bInterfaceSubClass", cInterfaceDescriptor_bInterfaceSubClass, 0);
  rb_define_method (rb_cInterfaceDescriptor, "bInterfaceProtocol", cInterfaceDescriptor_bInterfaceProtocol, 0);
  rb_define_method (rb_cInterfaceDescriptor, "iInterface", cInterfaceDescriptor_iInterface, 0);
  rb_define_method (rb_cInterfaceDescriptor, "endpointList", cInterfaceDescriptor_endpointList, 0);
  rb_define_method (rb_cInterfaceDescriptor, "extra", cInterfaceDescriptor_extra, 0);

  /* RibUSB::EndpointDescriptor -- a class for USB endpoint descriptors */
  rb_cEndpointDescriptor = rb_define_class_under (rb_mRibUSB, "EndpointDescriptor", rb_cObject);
  rb_define_method (rb_cEndpointDescriptor, "bLength", cEndpointDescriptor_bLength, 0);
  rb_define_method (rb_cEndpointDescriptor, "bDescriptorType", cEndpointDescriptor_bDescriptorType, 0);
  rb_define_method (rb_cEndpointDescriptor, "bEndpointAddress", cEndpointDescriptor_bEndpointAddress, 0);
  rb_define_method (rb_cEndpointDescriptor, "bmAttributes", cEndpointDescriptor_bmAttributes, 0);
  rb_define_method (rb_cEndpointDescriptor, "wMaxPacketSize", cEndpointDescriptor_wMaxPacketSize, 0);
  rb_define_method (rb_cEndpointDescriptor, "bInterval", cEndpointDescriptor_bInterval, 0);
  rb_define_method (rb_cEndpointDescriptor, "bRefresh", cEndpointDescriptor_bRefresh, 0);
  rb_define_method (rb_cEndpointDescriptor, "bSynchAddress", cEndpointDescriptor_bSynchAddress, 0);
  rb_define_method (rb_cEndpointDescriptor, "extra", cEndpointDescriptor_extra, 0);

  /* RibUSB::Transfer -- a class for USB transfers */
  rb_cTransfer = rb_define_class_under (rb_mRibUSB, "Transfer", rb_cObject);
  rb_define_singleton_method (rb_cTransfer, "new", cTransfer_new, 1);
  rb_define_method (rb_cTransfer, "submit", cTransfer_submit, 0);
  rb_define_method (rb_cTransfer, "cancel", cTransfer_cancel, 0);
  rb_define_method (rb_cTransfer, "fillControlTransfer", cTransfer_fillControlTransfer, 7);
}
