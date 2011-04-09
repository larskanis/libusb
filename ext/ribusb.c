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

#ifndef RSTRING_PTR
# define RSTRING_PTR(s) (RSTRING(s)->ptr)
# define RSTRING_LEN(s) (RSTRING(s)->len)
#endif

#ifndef HAS_RB_HASH_LOOKUP
# define rb_hash_lookup(k, v) rb_hash_aref(k, v)
#endif

#ifndef LIBUSB_CALL
# define LIBUSB_CALL
#endif

/******************************************************
* global variables                                   *
******************************************************/

static VALUE RibUSB;
static VALUE Context;
static VALUE Device;
static VALUE ConfigDescriptor;
static VALUE Interface;
static VALUE InterfaceDescriptor;
static VALUE EndpointDescriptor;
static VALUE Transfer;

static const char *VERSION = "0.1.0";

#define FOREACH_ERROR_CODE(func) \
  func(LIBUSB_ERROR_ACCESS, "access denied (insuffucient permissions)"); \
  func(LIBUSB_ERROR_BUSY, "resource busy"); \
  func(LIBUSB_ERROR_INTERRUPTED, "system call interrupted (perhaps due to signal)"); \
  func(LIBUSB_ERROR_INVALID_PARAM, "invalid parameter"); \
  func(LIBUSB_ERROR_IO, "input/output error"); \
  func(LIBUSB_ERROR_NO_DEVICE, "no such device"); \
  func(LIBUSB_ERROR_NO_MEM, "insufficient memory"); \
  func(LIBUSB_ERROR_NOT_FOUND, "entity not found"); \
  func(LIBUSB_ERROR_NOT_SUPPORTED, "operation not supported or unimplemented on this platform"); \
  func(LIBUSB_ERROR_OTHER, "other error"); \
  func(LIBUSB_ERROR_OVERFLOW, "overflow"); \
  func(LIBUSB_ERROR_PIPE, "pipe error"); \
  func(LIBUSB_ERROR_TIMEOUT, "operation timed out");

static VALUE eError;
#define DEFINE_STATIC_VALUE(name, desc) static VALUE e##name;
FOREACH_ERROR_CODE(DEFINE_STATIC_VALUE);

/******************************************************
* structures for classes                             *
******************************************************/

/*
* Opaque structure for the RibUSB::Context class
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
  const struct libusb_interface *interface;
};

/*
* Opaque structure for the RibUSB::InterfaceDescriptor class
*/
struct interface_descriptor_t {
  const struct libusb_interface_descriptor *descriptor;
};

/*
* Opaque structure for the RibUSB::EndpointDescriptor class
*/
struct endpoint_descriptor_t {
  const struct libusb_endpoint_descriptor *descriptor;
};

/*
* Opaque structure for the RibUSB::Transfer class
*/
struct transfer_t {
  struct libusb_transfer *transfer;
  unsigned char *buffer;
  VALUE proc;
  int foreign_data_in;
  unsigned char *foreign_data_in_ptr;
};



/******************************************************
* internal prototypes                                *
******************************************************/
static VALUE cDevice_new (struct libusb_device *device, VALUE context);
void cTransfer_free (struct transfer_t *t);
static VALUE cConfigDescriptor_new (struct libusb_config_descriptor *descriptor, VALUE device);
static VALUE cInterface_new (const struct libusb_interface *interface, VALUE config_descriptor);
static VALUE cInterfaceDescriptor_new (const struct libusb_interface_descriptor *descriptor, VALUE interface);
static VALUE cEndpointDescriptor_new (const struct libusb_endpoint_descriptor *descriptor, VALUE interface_descriptor);



/******************************************************
* internal functions                                 *
******************************************************/

static void LIBUSB_CALL callback_wrapper (struct libusb_transfer *transfer)
{
  struct transfer_t *t;

  Data_Get_Struct ((VALUE)(transfer->user_data), struct transfer_t, t);
  rb_funcall (t->proc, rb_intern("call"), 1, (VALUE *) transfer->user_data);
}

VALUE get_opt (VALUE hash, const char *key, int mandatory)
{
  VALUE opt;

  opt = rb_hash_lookup (hash, ID2SYM(rb_intern (key)));
  if (mandatory && (opt == Qnil)) {
    rb_raise (rb_eArgError, "Option :%s not specified.", key);
  }
  return opt;
}

static void raise_error(int error_code, const char *text)
{
  #define DEFINE_ERROR_CASE(name, desc) \
    case name: \
      rb_raise (e##name, "%s: " desc, text); \
      break;

  switch(error_code){
    FOREACH_ERROR_CODE(DEFINE_ERROR_CASE);
    default:
      rb_raise(eError, "%s: unknown error code %d", text, error_code); \
  }
}


/******************************************************
* RibUSB::Context method definitions                     *
******************************************************/

void cContext_free (struct usb_t *u)
{
  libusb_exit (u->context);

  xfree (u);
}

/*
* call-seq:
*   RibUSB::Context.new -> bus
*
* Create an instance of RibUSB::Context.
*
* Effectively creates a _libusb_ context (the context itself being stored in an opaque structure). The memory associated with the bus is automatically freed on garbage collection when possible.
*
* If successful, returns the bus object, otherwise raises an exception and returns either +nil+ or the _libusb_ error code (+FixNum+).
*/
static VALUE cContext_new (VALUE self)
{
  struct libusb_context *context;
  struct usb_t *u;
  int res;
  VALUE object;

  res = libusb_init (&context);
  if (res) {
    raise_error(res, "Failed to initialize libusb");
  }
  u = ALLOC(struct usb_t);
  u->context = context;
  object = Data_Wrap_Struct (Context, NULL, cContext_free, u);
  rb_obj_call_init (object, 0, 0);
  return object;
}

/*
* call-seq:
*   bus.set_debug(level) -> nil
*   bus.debug=level -> nil
*
* Set the debug level of the current _libusb_ context.
*
* - +level+ is a +FixNum+ with a sensible range from 0 to 3.
*
* Returns +nil+ and never raises an exception.
*/
static VALUE cContext_set_debug (VALUE self, VALUE level)
{
  struct usb_t *u;

  Data_Get_Struct (self, struct usb_t, u);
  libusb_set_debug (u->context, NUM2INT(level));
  return Qnil;
}

/*
* call-seq:
*   bus.find -> list
*   bus.find {block} -> list
*   bus.find(hash) -> list
*   bus.find(hash) {block} -> list
*
* Obtain a list of devices currently attached to the USB system, optionally matching certain criteria.
*
* Criteria can, optionally, be supplied in the form of a hash, or in a block, or both.
* - In the hash, a number of simple criteria can be defined. If a criterion is not specified or its value is +nil+, any device will match that criterion.
*   * <tt>:idVendor</tt>, <tt>:idProduct</tt> (+FixNum+) for the vendor/product ID;
*   * <tt>:bcdUSB</tt>, <tt>:bcdDevice</tt> (+FixNum+) for the USB and device release numbers;
*   * <tt>:bDeviceClass</tt>, <tt>:bDeviceSubClass</tt>, <tt>:bDeviceProtocol</tt>, <tt>:bMaxPacketSize0</tt> (+FixNum+) for the device type.
* - The block is called for all devices that match the criteria specified in the hash.
* - The block is passed a single argument: the RibUSB::Device instance of the device. The device is included in the resulting list if and only if the block returns non-+false+.
* - If the block is not specified, all devices matching the hash criteria are returned.
*
* On success, returns an array of RibUSB::Device with one entry for each device, otherwise raises an exception and returns the _libusb_ error code (+FixNum+).
*
* Note: this list provides no information whatsoever on whether or not any given device can be accessed. Insufficient privilege and use by other software can prevent access to any device.
*/
static VALUE cContext_find (int argc, VALUE *argv, VALUE self)
{
  struct usb_t *u;
  struct libusb_device **list;
  struct device_t *d;
  ssize_t res;
  VALUE device, array;
  int i;
  VALUE v;
  uint8_t bDeviceClass = 0, bDeviceSubClass = 0, bDeviceProtocol = 0, bMaxPacketSize0 = 0;
  uint16_t bcdUSB = 0, idVendor = 0, idProduct = 0, bcdDevice = 0;
  uint16_t mask = 0;
  VALUE hash, proc;

  rb_scan_args (argc, argv, "01&", &hash, &proc);
  if (!NIL_P(hash)) {
    if (rb_type(hash) == T_HASH) {
      v = rb_hash_lookup (hash, ID2SYM(rb_intern ("bDeviceClass")));
      if (!NIL_P(v)) {
        bDeviceClass = NUM2INT(v);
        mask |= 0x01;
      }
      v = rb_hash_lookup (hash, ID2SYM(rb_intern ("bDeviceSubClass")));
      if (!NIL_P(v)) {
        bDeviceSubClass = NUM2INT(v);
        mask |= 0x02;
      }
      v = rb_hash_lookup (hash, ID2SYM(rb_intern ("bDeviceProtocol")));
      if (!NIL_P(v)) {
        bDeviceProtocol = NUM2INT(v);
        mask |= 0x04;
      }
      v = rb_hash_lookup (hash, ID2SYM(rb_intern ("bMaxPacketSize0")));
      if (!NIL_P(v)) {
        bMaxPacketSize0 = NUM2INT(v);
        mask |= 0x08;
      }
      v = rb_hash_lookup (hash, ID2SYM(rb_intern ("bcdUSB")));
      if (!NIL_P(v)) {
        bcdUSB = NUM2INT(v);
        mask |= 0x10;
      }
      v = rb_hash_lookup (hash, ID2SYM(rb_intern ("idVendor")));
      if (!NIL_P(v)) {
        idVendor = NUM2INT(v);
        mask |= 0x20;
      }
      v = rb_hash_lookup (hash, ID2SYM(rb_intern ("idProduct")));
      if (!NIL_P(v)) {
        idProduct = NUM2INT(v);
        mask |= 0x40;
      }
      v = rb_hash_lookup (hash, ID2SYM(rb_intern ("bcdDevice")));
      if (!NIL_P(v)) {
        bcdDevice = NUM2INT(v);
        mask |= 0x80;
      }
    } else
      rb_raise (rb_eArgError, "Argument to RibUSB::Context#find must be a hash or nil, if specified.");
  }

  Data_Get_Struct (self, struct usb_t, u);

  res = libusb_get_device_list (u->context, &list);

  if (res < 0) {
    raise_error( res, "Failed to allocate memory for list of devices" );
  }

  array = rb_ary_new ();

  for (i = 0; i < res; i ++) {
    device = cDevice_new (list[i], self);               /* XXX not very nice */
    Data_Get_Struct (device, struct device_t, d); /* XXX not very nice */
    if ((mask & 0x01) && (bDeviceClass != d->descriptor->bDeviceClass))
      continue;
    if ((mask & 0x02) && (bDeviceSubClass != d->descriptor->bDeviceSubClass))
      continue;
    if ((mask & 0x04) && (bDeviceProtocol != d->descriptor->bDeviceProtocol))
      continue;
    if ((mask & 0x08) && (bMaxPacketSize0 != d->descriptor->bMaxPacketSize0))
      continue;
    if ((mask & 0x10) && (bcdUSB != d->descriptor->bcdUSB))
      continue;
    if ((mask & 0x20) && (idVendor != d->descriptor->idVendor))
      continue;
    if ((mask & 0x40) && (idProduct != d->descriptor->idProduct))
      continue;
    if ((mask & 0x80) && (bcdDevice != d->descriptor->bcdDevice))
      continue;

    if (!NIL_P(proc))
      if (rb_funcall (proc, rb_intern ("call"), 1, device) == Qfalse)
        continue;

    rb_ary_push (array, device);
  }

  libusb_free_device_list (list, 1);

  return array;
}

/*
* call-seq:
*   RibUSB::Context.handle_events -> nil
*
* Handles all pending USB events on the bus.
*
* If successful, returns +nil+, otherwise raises an exception and returns either the _libusb_ error code (+FixNum+).
*/
static VALUE cContext_handle_events (VALUE self)
{
  struct usb_t *u;
  int res;

  Data_Get_Struct (self, struct usb_t, u);
  res = libusb_handle_events (u->context);
  if (res) {
    raise_error( res, "Failed to handle pending USB events" );
  }
  return Qnil;
}



/******************************************************
* RibUSB::Device method definitions                  *
******************************************************/

void cDevice_free (struct device_t *d)
{
  if (d->handle)
    libusb_close (d->handle);

  libusb_unref_device (d->device);

  xfree (d);
}

/* XXXXXX does this need to be a separate function??? */
static VALUE cDevice_new (struct libusb_device *device, VALUE context)
{
  struct device_t *d;
  VALUE object;
  int res;

  d = ALLOC(struct device_t);
  libusb_ref_device (device);
  d->device = device;
  d->handle = NULL;
  d->descriptor = ALLOC(struct libusb_device_descriptor);
  res = libusb_get_device_descriptor (d->device, d->descriptor);
  if (res < 0){
    xfree(d);
    xfree(d->descriptor);
    raise_error( res, "Failed to retrieve device descriptor" );
  }

  object = Data_Wrap_Struct (Device, NULL, cDevice_free, d);
  rb_iv_set(object, "@context", context);
  rb_obj_call_init (object, 0, 0);
  return object;
}

static void ensure_open_device(struct device_t *d)
{
  int res;
  if (d->handle == NULL) {
    res = libusb_open (d->device, &(d->handle));
    if (res < 0) {
      raise_error( res, "Failed to open USB device");
    }
  }
}

/*
* call-seq:
*   device.close
*
* Explicitly close an obtained device handle. This is also done by GC.
*/
static VALUE cDevice_close (VALUE self)
{
  struct device_t *d;

  Data_Get_Struct (self, struct device_t, d);
  if (d->handle)
    libusb_close (d->handle);
  d->handle = NULL;

  return Qnil;
}

/*
* call-seq:
*   device.get_bus_number -> bus_number
*   device.bus_number -> bus_number
*
* Get bus number.
*
* On success, returns the USB bus number (+FixNum+) the device is connected to, otherwise raises an exception and returns the _libusb_ error code (+FixNum+).
*/
static VALUE cDevice_get_bus_number (VALUE self)
{
  struct device_t *d;
  int res;

  Data_Get_Struct (self, struct device_t, d);
  res = libusb_get_bus_number (d->device);
  if (res < 0)
    raise_error( res, "Failed to retrieve device bus number" );
  return INT2NUM(res);
}

/*
* call-seq:
*   device.get_device_address -> address
*   device.device_address -> address
*
* Get device address.
*
* On success, returns the USB address on the bus (+FixNum+), otherwise raises an exception and returns the _libusb_ error code (+FixNum+).
*/
static VALUE cDevice_get_device_address (VALUE self)
{
  struct device_t *d;
  int res;

  Data_Get_Struct (self, struct device_t, d);
  res = libusb_get_device_address (d->device);
  if (res < 0)
    raise_error( res, "Failed to retrieve device address" );
  return INT2NUM(res);
}

/*
* call-seq:
*   device.get_max_packet_size(endpoint) -> max_packet_size
*   device.max_packet_size(endpoint) -> max_packet_size
*
* Get maximum packet size.
*
* - +endpoint+ is a +FixNum+ containing the endpoint number.
*
* On success, returns the maximum packet size of the endpoint (+FixNum+), otherwise raises an exception and returns the _libusb_ error code (+FixNum+).
*/
static VALUE cDevice_get_max_packet_size (VALUE self, VALUE endpoint)
{
  struct device_t *d;
  int res;

  Data_Get_Struct (self, struct device_t, d);
  res = libusb_get_max_packet_size (d->device, NUM2INT(endpoint));
  if (res < 0)
    raise_error( res, "Failed to retrieve maximum packet size of endpoint" );
  return INT2NUM(res);
}

/*
* call-seq:
*   device.get_configuration -> configuration
*   device.configuration -> configuration
*
* Get currently active configuration.
*
* On success, returns the bConfigurationValue of the active configuration of the device (+FixNum+), otherwise raises an exception and returns the _libusb_ error code (+FixNum+).
*/
static VALUE cDevice_get_configuration (VALUE self)
{
  struct device_t *d;
  int res;
  int c;

  Data_Get_Struct (self, struct device_t, d);
  ensure_open_device(d);
  res = libusb_get_configuration (d->handle, &c);
  if (res < 0)
    raise_error( res, "Failed to obtain configuration value" );
  return INT2NUM(c);
}

/*
* call-seq:
*   device.set_configuration(configuration) -> nil
*   device.configuration=(configuration) -> nil
*
* Set active configuration.
*
* - +configuration+ is a +FixNum+ containing the configuration number.
*
* Returns +nil+ in any case, and raises an exception on failure.
*/
static VALUE cDevice_set_configuration (VALUE self, VALUE configuration)
{
  struct device_t *d;
  int res;

  Data_Get_Struct (self, struct device_t, d);
  ensure_open_device(d);
  res = libusb_set_configuration (d->handle, NUM2INT(configuration));
  if (res < 0)
    raise_error( res, "Failed to set configuration" );
  return INT2NUM(res);
}

/*
* call-seq:
*   device.claim_interface(interface) -> nil
*
* Claim interface.
*
* - +interface+ is a +FixNum+ containing the interface number.
*
* Returns +nil+ in any case, and raises an exception on failure.
*/
static VALUE cDevice_claim_interface (VALUE self, VALUE interface)
{
  struct device_t *d;
  int res;

  Data_Get_Struct (self, struct device_t, d);
  ensure_open_device(d);
  res = libusb_claim_interface (d->handle, NUM2INT(interface));
  if (res < 0)
    raise_error( res, "Failed to claim interface" );
  return INT2NUM(res);
}

/*
* call-seq:
*   device.release_interface(interface) -> nil
* Release interface.
*
* - +interface+ is a +FixNum+ containing the interface number.
*
* Returns +nil+ in any case, and raises an exception on failure.
*/
static VALUE cDevice_release_interface (VALUE self, VALUE interface)
{
  struct device_t *d;
  int res;

  Data_Get_Struct (self, struct device_t, d);
  ensure_open_device(d);
  res = libusb_release_interface (d->handle, NUM2INT(interface));
  if (res < 0)
    raise_error( res, "Failed to release interface" );
  return INT2NUM(res);
}

/*
* call-seq:
*   device.set_interface_alt_setting(interface, setting) -> nil
*
* Set alternate setting for an interface.
*
* - +interface+ is a +FixNum+ containing the interface number.
* - +setting+ is a +FixNum+ containing the alternate setting number.
*
* Returns +nil+ in any case, and raises an exception on failure.
*/
static VALUE cDevice_set_interface_alt_setting (VALUE self, VALUE interface, VALUE setting)
{
  struct device_t *d;
  int res;

  Data_Get_Struct (self, struct device_t, d);
  ensure_open_device(d);
  res = libusb_set_interface_alt_setting (d->handle, NUM2INT(interface), NUM2INT(setting));
  if (res < 0)
    raise_error( res, "Failed to set interface alternate setting" );
  return INT2NUM(res);
}

/*
* call-seq:
*   device.clear_halt(endpoint) -> nil
*
* Clear halt/stall condition for an endpoint.
*
* - +endpoint+ is a +FixNum+ containing the endpoint number.
*
* Returns +nil+ in any case, and raises an exception on failure.
*/
static VALUE cDevice_clear_halt (VALUE self, VALUE endpoint)
{
  struct device_t *d;
  int res;

  Data_Get_Struct (self, struct device_t, d);
  ensure_open_device(d);
  res = libusb_clear_halt (d->handle, NUM2INT(endpoint));
  if (res < 0)
    raise_error( res, "Failed to clear halt/stall condition" );
  return INT2NUM(res);
}

/*
* call-seq: device.reset_device -> nil
*
* Reset device.
*
* Returns +nil+ in any case, and raises an exception on failure.
*/
static VALUE cDevice_reset_device (VALUE self)
{
  struct device_t *d;
  int res;

  Data_Get_Struct (self, struct device_t, d);
  ensure_open_device(d);
  res = libusb_reset_device (d->handle);
  if (res < 0)
    raise_error( res, "Failed to reset device" );
  return INT2NUM(res);
}

/*
* call-seq:
*   device.kernel_driver_active?(interface) -> result
*
* Determine if a kernel driver is active on a given interface.
*
* - +interface+ is a +FixNum+ containing the interface number.
*
* On success, returns whether or not the device interface is claimed by a kernel driver (+true+ or +false+), otherwise raises an exception and returns the _libusb_ error code (+FixNum+).
*/
static VALUE cDevice_kernel_driver_activeQ (VALUE self, VALUE interface)
{
  struct device_t *d;
  int res;

  Data_Get_Struct (self, struct device_t, d);
  ensure_open_device(d);
  res = libusb_kernel_driver_active (d->handle, NUM2INT(interface));
  if (res < 0) {
    raise_error( res, "Failed to determine whether a kernel driver is active on interface" );
  } else if (res == 1)
    return Qtrue;
  return Qfalse;
}

/*
* call-seq:
*   device.detach_kernel_driver(interface) -> nil
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
  ensure_open_device(d);
  res = libusb_detach_kernel_driver (d->handle, NUM2INT(interface));
  if (res < 0)
    raise_error( res, "Failed to detach kernel driver" );
  return INT2NUM(res);
}

/*
* call-seq:
*   device.attach_kernel_driver(interface) -> nil
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
  ensure_open_device(d);
  res = libusb_attach_kernel_driver (d->handle, NUM2INT(interface));
  if (res < 0)
    raise_error( res, "Failed to re-attach kernel driver" );
  return INT2NUM(res);
}

/*
* call-seq:
*   device.get_string_descriptor_ascii(index) -> desc
*   device.string_descriptor_ascii(index) -> desc
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
  ensure_open_device(d);
  res = libusb_get_string_descriptor_ascii (d->handle, NUM2INT(index), (unsigned char *) c, sizeof (c));
  if (res < 0)
    raise_error( res, "Failed to retrieve descriptor string" );
  return rb_str_new(c, res);
}

/*
* call-seq:
*   device.get_string_descriptor(index, langid) -> desc
*   device.string_descriptor(index, langid) -> desc
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
  ensure_open_device(d);
  res = libusb_get_string_descriptor (d->handle, NUM2INT(index), NUM2INT(langid), (unsigned char *) c, sizeof (c));
  if (res < 0)
    raise_error( res, "Failed to retrieve descriptor string" );
  return rb_str_new(c, res);
}

/*
* call-seq:
*   device.control_transfer(args) -> count
*   device.control_transfer(args) -> data
*   device.control_transfer(args) {block} -> transfer
*
* Perform or prepare a control transfer.
*
* - +args+ is a +Hash+ containing all options, which are mandatory unless otherwise specified:
*   * <tt>:bmRequestType</tt> is a +FixNum+ specifying the 8-bit request type field of the setup packet (note that the direction bit is ignored).
*   * <tt>:bRequest</tt> is a +FixNum+ specifying the 8-bit request field of the setup packet.
*   * <tt>:wValue</tt> is a +FixNum+ specifying the 16-bit value field of the setup packet.
*   * <tt>:wIndex</tt> is a +FixNum+ specifying the 16-bit index field of the setup packet.
*   * <tt>:dataIn</tt> is optional and either a +String+ or a +FixNum+, see below.
*   * <tt>:dataOut</tt> is an optional +String+, see below.
*   * <tt>:timeout</tt> is an optional +FixNum+ specifying the timeout for this transfer in milliseconds; default is 1000.
* - <tt>:dataIn</tt> and <tt>:dataOut</tt> are mutually exclusive but neither is mandatory.
* - The type and direction of the transfer is determined as follows:
*   * If a block is passed, the transfer is asynchronous and the method returns immediately. Otherwise, the transfer is synchronous and the method returns when the transfer has completed or timed out.
*   * If neither <tt>:dataIn</tt> nor <tt>:dataOut</tt> is specified, the transfer will only contain the setup packet but no data packet.
*   * If <tt>:dataIn</tt> is a +Fixnum+, an +in+ transfer is started; its value must be between 1 and 64 and specifies the size of the data packet. A new +String+ is created for the data received if the transfer is successful.
*   * If <tt>:dataIn</tt> is a +String+, an +in+ transfer is started; its size must be between 1 and 64 and specifies the size of the data packet; data received is stored in this +String+.
*   * If <tt>:dataOut</tt> is a +String+, an +out+ transfer is started; its size must be between 1 and 64 and specifies the size of the data packet; the contents of this +String+ are sent as the data packet.
* - If no block is passed, perform the transfer immediately and block until the transfer has completed or timed out, or until any other error occurs.
* - If a block is passed, prepare and return a RibUSB::Transfer without starting any USB transaction.
*
* On success, returns one of the following, otherwise raises an exception and returns +nil+ or the _libusb_ error code (+FixNum+):
* - a RibUSB::Transfer if the transfer is asynchronous;
* - <tt>0</tt> if neither <tt>:dataIn</tt> nor <tt>:dataOut</tt> is specified;
* - the number of bytes transferred if either <tt>:dataIn</tt> or <tt>:dataOut</tt> is a +String+;
* - a +String+ containing the data packet if <tt>:dataIn</tt> is a +Fixnum+.
*/
static VALUE cDevice_control_transfer (VALUE self, VALUE hash)
{
  struct device_t *d;
  uint8_t bmRequestType, bRequest;
  uint16_t wValue, wIndex;
  VALUE dataIn, dataOut;
  unsigned char *data;
  int foreign_data_in = 1;
  uint16_t wLength;
  unsigned int timeout;
  VALUE v;
  int res;
  struct transfer_t *t;
  VALUE object;

  Data_Get_Struct (self, struct device_t, d);
  ensure_open_device(d);

  bmRequestType = NUM2INT(get_opt (hash, "bmRequestType", 1));
  bRequest = NUM2INT(get_opt (hash, "bRequest", 1));
  wValue = NUM2INT(get_opt (hash, "wValue", 1));
  wIndex = NUM2INT(get_opt (hash, "wIndex", 1));
  dataIn = get_opt (hash, "dataIn", 0);
  dataOut = get_opt (hash, "dataOut", 0);

  if ((!NIL_P(dataIn)) && (NIL_P(dataOut))) {
    bmRequestType |= 0x80; /* in transfer */
    switch (TYPE(dataIn)) {
    case T_STRING:
      data = (unsigned char *) (RSTRING_PTR(dataIn));
      wLength = RSTRING_LEN(dataIn);
      foreign_data_in = 1;
      break;
    case T_FIXNUM:
      wLength = NUM2INT(dataIn);
      data = NULL;
      foreign_data_in = 0;
      break;
    default:
      rb_raise (rb_eArgError, "Option :dataIn must be either a String or a Fixnum in RibUSB::Device#control_transfer.");
    }
  } else if ((NIL_P(dataIn)) && (!NIL_P(dataOut))) {
    bmRequestType &= 0x7f; /* out transfer */
    data = (unsigned char *) (RSTRING_PTR(dataOut));
    wLength = RSTRING_LEN(dataOut);
  } else if ((NIL_P(dataIn)) && (NIL_P(dataOut))) {
    bmRequestType &= 0x7f; /* out transfer */
    data = NULL;
    wLength = 0;
  } else
    rb_raise (rb_eArgError, "Options :dataIn and :dataOut must not both be non-nil in RibUSB::Device#control_transfer.");

  v = get_opt (hash, "timeout", 0);
  if (NIL_P(v))
    timeout = 1000;
  else
    timeout = NUM2INT(v);

  if (rb_block_given_p ()) {
    t = ALLOC(struct transfer_t);
    t->foreign_data_in = foreign_data_in;
    t->foreign_data_in_ptr = data;
    t->proc = rb_block_proc ();
    t->transfer = libusb_alloc_transfer (0);
    if (!(t->transfer)) {
      rb_raise (rb_eNoMemError, "Failed to allocate control transfer.");
    }
    t->buffer = (unsigned char *) xmalloc (LIBUSB_CONTROL_SETUP_SIZE + wLength);
    libusb_fill_control_setup (t->buffer, bmRequestType, bRequest, wValue, wIndex, wLength);
    if (data) {
      memcpy(t->buffer + LIBUSB_CONTROL_SETUP_SIZE, data, wLength);
    }
    object = Data_Wrap_Struct (Transfer, NULL, cTransfer_free, t);
    libusb_fill_control_transfer (t->transfer, d->handle, t->buffer, callback_wrapper, (void *) object, timeout);

    rb_obj_call_init (object, 0, 0);
    /* don't GC dataIn, as long as transfer isn't */
    rb_iv_set(object, "@dataIn", dataIn);
    return object;
  } else {
    if( !foreign_data_in )
      data = (unsigned char *) xmalloc (wLength);

    res = libusb_control_transfer (d->handle, bmRequestType, bRequest, wValue, wIndex, data, wLength, timeout);
    if (res < 0)
      raise_error( res, "Synchronous control transfer failed" );
    if (foreign_data_in)
      return INT2NUM(res);
    else {
      v = rb_str_new ((char *) data, res);
      xfree (data);
      return v;
    }
  }
}

/*
* call-seq:
*   device.bulk_transfer(args) -> count
*   device.bulk_transfer(args) -> data
*   device.bulk_transfer(args) {block} -> transfer
*
* Perform or prepare a bulk transfer.
*
* - +args+ is a +Hash+ containing all options, which are mandatory unless otherwise specified:
*   * <tt>:endpoint</tt> is a +FixNum+ specifying the USB endpoint (note that the direction bit is ignored).
*   * <tt>:dataIn</tt> is optional and either a +String+ or a +FixNum+, see below.
*   * <tt>:dataOut</tt> is an optional +String+, see below.
*   * <tt>:timeout</tt> is an optional +FixNum+ specifying the timeout for this transfer in milliseconds; default is 1000.
* - Exactly one of <tt>:dataIn</tt> and <tt>:dataOut</tt> must be specified.
* - The type and direction of the transfer is determined as follows:
*   * If a block is passed, the transfer is asynchronous and the method returns immediately. Otherwise, the transfer is synchronous and the method returns when the transfer has completed or timed out.
*   * If <tt>:dataIn</tt> is a +Fixnum+, an +in+ transfer is started; its value specifies the size of the data packet. A new +String+ is created for the data received if the transfer is successful.
*   * If <tt>:dataIn</tt> is a +String+, an +in+ transfer is started; its size specifies the size of the data packet; data received is stored in this +String+.
*   * If <tt>:dataOut</tt> is a +String+, an +out+ transfer is started; its size specifies the size of the data packet; the contents of this +String+ are sent as the data packet.
* - If no block is passed, perform the transfer immediately and block until the transfer has completed or timed out, or until any other error occurs.
* - If a block is passed, prepare and return a RibUSB::Transfer without starting any USB transaction.
*
* On success, returns one of the following, otherwise raises an exception and returns +nil+ or the _libusb_ error code (+FixNum+):
* - a RibUSB::Transfer if the transfer is asynchronous;
* - the number of bytes transferred if either <tt>:dataIn</tt> or <tt>:dataOut</tt> is a +String+;
* - a +String+ containing the data packet if <tt>:dataIn</tt> is a +Fixnum+.
*/
static VALUE cDevice_bulk_transfer (VALUE self, VALUE hash)
{
  struct device_t *d;
  unsigned char endpoint;
  VALUE dataIn, dataOut;
  unsigned char *data;
  int foreign_data_in = 1;
  uint16_t wLength;
  unsigned int timeout;
  VALUE v;
  int res, transferred;
  struct transfer_t *t;
  VALUE object;

  Data_Get_Struct (self, struct device_t, d);
  ensure_open_device(d);

  endpoint = NUM2INT(get_opt (hash, "endpoint", 1));
  dataIn = get_opt (hash, "dataIn", 0);
  dataOut = get_opt (hash, "dataOut", 0);

  if ((!NIL_P(dataIn)) && (NIL_P(dataOut))) {
    endpoint |= 0x80; /* in transfer */
    switch (TYPE(dataIn)) {
    case T_STRING:
      data = (unsigned char *) (RSTRING_PTR(dataIn));
      wLength = RSTRING_LEN(dataIn);
      foreign_data_in = 1;
      break;
    case T_FIXNUM:
      wLength = NUM2INT(dataIn);
      data = (unsigned char *) xmalloc (wLength);
      foreign_data_in = 0;
      break;
    default:
      rb_raise (rb_eArgError, "Option :dataIn must be either a String or a Fixnum in RibUSB::Device#bulk_transfer.");
    }
  } else if ((NIL_P(dataIn)) && (!NIL_P(dataOut))) {
    endpoint &= 0x7f; /* out transfer */
    data = (unsigned char *) (RSTRING_PTR(dataOut));
    wLength = RSTRING_LEN(dataOut);
  } else
    rb_raise (rb_eArgError, "Exactly one of :dataIn and :dataOut must be non-nil in RibUSB::Device#bulk_transfer.");

  v = get_opt (hash, "timeout", 0);
  if (NIL_P(v))
    timeout = 1000;
  else
    timeout = NUM2INT(v);

  if (rb_block_given_p ()) {
    t = ALLOC(struct transfer_t);
    t->foreign_data_in = foreign_data_in;
    t->proc = rb_block_proc ();
    t->transfer = libusb_alloc_transfer (0);
    if (!(t->transfer)) {
      rb_raise (rb_eNoMemError, "Failed to allocate bulk transfer.");
    }
    t->buffer = foreign_data_in ? NULL : data;
    object = Data_Wrap_Struct (Transfer, NULL, cTransfer_free, t);
    libusb_fill_bulk_transfer (t->transfer, d->handle, endpoint, data, wLength, callback_wrapper, (void *) object, timeout);

    rb_obj_call_init (object, 0, 0);
    /* don't GC dataIn, as long as transfer isn't */
    rb_iv_set(object, "@dataIn", dataIn);
    return object;
  } else {
    res = libusb_bulk_transfer (d->handle, endpoint, data, wLength, &transferred, timeout);
    if (res < 0)
      raise_error( res, "Synchronous bulk transfer failed" );
    if (foreign_data_in)
      return INT2NUM(transferred);
    else {
      v = rb_str_new ((char *) data, transferred);
      xfree (data);
      return v;
    }
  }
}

/*
* call-seq:
*   device.interrupt_transfer(args) -> count
*   device.interrupt_transfer(args) -> data
*   device.interrupt_transfer(args) {block} -> transfer
*
* Perform or prepare a interrupt transfer.
*
* - +args+ is a +Hash+ containing all options, which are mandatory unless otherwise specified:
*   * <tt>:endpoint</tt> is a +FixNum+ specifying the USB endpoint (note that the direction bit is ignored).
*   * <tt>:dataIn</tt> is optional and either a +String+ or a +FixNum+, see below.
*   * <tt>:dataOut</tt> is an optional +String+, see below.
*   * <tt>:timeout</tt> is an optional +FixNum+ specifying the timeout for this transfer in milliseconds; default is 1000.
* - Exactly one of <tt>:dataIn</tt> and <tt>:dataOut</tt> must be specified.
* - The type and direction of the transfer is determined as follows:
*   * If a block is passed, the transfer is asynchronous and the method returns immediately. Otherwise, the transfer is synchronous and the method returns when the transfer has completed or timed out.
*   * If <tt>:dataIn</tt> is a +Fixnum+, an +in+ transfer is started; its value specifies the size of the data packet. A new +String+ is created for the data received if the transfer is successful.
*   * If <tt>:dataIn</tt> is a +String+, an +in+ transfer is started; its size specifies the size of the data packet; data received is stored in this +String+.
*   * If <tt>:dataOut</tt> is a +String+, an +out+ transfer is started; its size specifies the size of the data packet; the contents of this +String+ are sent as the data packet.
* - If no block is passed, perform the transfer immediately and block until the transfer has completed or timed out, or until any other error occurs.
* - If a block is passed, prepare and return a RibUSB::Transfer without starting any USB transaction.
*
* On success, returns one of the following, otherwise raises an exception and returns +nil+ or the _libusb_ error code (+FixNum+):
* - a RibUSB::Transfer if the transfer is asynchronous;
* - the number of bytes transferred if either <tt>:dataIn</tt> or <tt>:dataOut</tt> is a +String+;
* - a +String+ containing the data packet if <tt>:dataIn</tt> is a +Fixnum+.
*/
static VALUE cDevice_interrupt_transfer (VALUE self, VALUE hash)
{
  struct device_t *d;
  unsigned char endpoint;
  VALUE dataIn, dataOut;
  unsigned char *data;
  int foreign_data_in = 1;
  uint16_t wLength;
  unsigned int timeout;
  VALUE v;
  int res, transferred;
  struct transfer_t *t;
  VALUE object;

  Data_Get_Struct (self, struct device_t, d);
  ensure_open_device(d);

  endpoint = NUM2INT(get_opt (hash, "endpoint", 1));
  dataIn = get_opt (hash, "dataIn", 0);
  dataOut = get_opt (hash, "dataOut", 0);

  if ((!NIL_P(dataIn)) && (NIL_P(dataOut))) {
    endpoint |= 0x80; /* in transfer */
    switch (TYPE(dataIn)) {
    case T_STRING:
      data = (unsigned char *) (RSTRING_PTR(dataIn));
      wLength = RSTRING_LEN(dataIn);
      foreign_data_in = 1;
      break;
    case T_FIXNUM:
      wLength = NUM2INT(dataIn);
      data = (unsigned char *) xmalloc (wLength);
      foreign_data_in = 0;
      break;
    default:
      rb_raise (rb_eArgError, "Option :dataIn must be either a String or a Fixnum in RibUSB::Device#interrupt_transfer.");
    }
  } else if ((NIL_P(dataIn)) && (!NIL_P(dataOut))) {
    endpoint &= 0x7f; /* out transfer */
    data = (unsigned char *) (RSTRING_PTR(dataOut));
    wLength = RSTRING_LEN(dataOut);
  } else
    rb_raise (rb_eArgError, "Exactly one of :dataIn and :dataOut must be non-nil in RibUSB::Device#interrupt_transfer.");

  v = get_opt (hash, "timeout", 0);
  if (NIL_P(v))
    timeout = 1000;
  else
    timeout = NUM2INT(v);

  if (rb_block_given_p ()) {
    t = ALLOC(struct transfer_t);
    t->foreign_data_in = foreign_data_in;
    t->proc = rb_block_proc ();
    t->transfer = libusb_alloc_transfer (0);
    if (!(t->transfer)) {
      rb_raise (rb_eNoMemError, "Failed to allocate interrupt transfer.");
    }
    t->buffer = foreign_data_in ? NULL : data;
    object = Data_Wrap_Struct (Transfer, NULL, cTransfer_free, t);
    libusb_fill_interrupt_transfer (t->transfer, d->handle, endpoint, data, wLength, callback_wrapper, (void *) object, timeout);

    rb_obj_call_init (object, 0, 0);
    /* don't GC dataIn, as long as transfer isn't */
    rb_iv_set(object, "@dataIn", dataIn);
    return object;
  } else {
    res = libusb_interrupt_transfer (d->handle, endpoint, data, wLength, &transferred, timeout);
    if (res < 0)
      raise_error( res, "Synchronous interrupt transfer failed" );
    if (foreign_data_in)
      return INT2NUM(transferred);
    else {
      v = rb_str_new ((char *) data, transferred);
      xfree (data);
      return v;
    }
  }
}

/*
* call-seq:
*   device.bcdUSB -> bcdUSB
*
* Get the USB specification release number in binary-coded decimal.
*
* Returns a +FixNum+ and never raises an exception.
*/
static VALUE cDevice_bcdUSB (VALUE self)
{
  struct device_t *d;

  Data_Get_Struct (self, struct device_t, d);
  return INT2NUM(d->descriptor->bcdUSB);
}

/*
* call-seq:
*   device.bDeviceClass -> bDeviceClass
*
* Get the USB class code.
*
* Returns a +FixNum+ and never raises an exception.
*/
static VALUE cDevice_bDeviceClass (VALUE self)
{
  struct device_t *d;

  Data_Get_Struct (self, struct device_t, d);
  return INT2NUM(d->descriptor->bDeviceClass);
}

/*
* call-seq:
*   device.bDeviceSubClass -> bDeviceSubClass
*
* Get the USB subclass code.
*
* Returns a +FixNum+ and never raises an exception.
*/
static VALUE cDevice_bDeviceSubClass (VALUE self)
{
  struct device_t *d;

  Data_Get_Struct (self, struct device_t, d);
  return INT2NUM(d->descriptor->bDeviceSubClass);
}

/*
* call-seq:
*   device.bDeviceProtocol -> bDeviceProtocol
*
* Get the USB protocol code.
*
* Returns a +FixNum+ and never raises an exception.
*/
static VALUE cDevice_bDeviceProtocol (VALUE self)
{
  struct device_t *d;

  Data_Get_Struct (self, struct device_t, d);
  return INT2NUM(d->descriptor->bDeviceProtocol);
}

/*
* call-seq:
*   device.bMaxPacketSize0 -> bMaxPacketSize0
*
* Get the maximum packet size for endpoint 0.
*
* Returns a +FixNum+ and never raises an exception.
*/
static VALUE cDevice_bMaxPacketSize0 (VALUE self)
{
  struct device_t *d;

  Data_Get_Struct (self, struct device_t, d);
  return INT2NUM(d->descriptor->bMaxPacketSize0);
}

/*
* call-seq:
*   device.idVendor -> idVendor
*
* Get the vendor ID.
*
* Returns a +FixNum+ and never raises an exception.
*/
static VALUE cDevice_idVendor (VALUE self)
{
  struct device_t *d;

  Data_Get_Struct (self, struct device_t, d);
  return INT2NUM(d->descriptor->idVendor);
}

/*
* call-seq:
*   device.idProduct -> idProduct
*
* Get the product ID.
*
* Returns a +FixNum+ and never raises an exception.
*/
static VALUE cDevice_idProduct (VALUE self)
{
  struct device_t *d;

  Data_Get_Struct (self, struct device_t, d);
  return INT2NUM(d->descriptor->idProduct);
}

/*
* call-seq:
*   device.bcdDevice -> bcdDevice
*
* Get the device release number in binary-coded decimal.
*
* Returns a +FixNum+ and never raises an exception.
*/
static VALUE cDevice_bcdDevice (VALUE self)
{
  struct device_t *d;

  Data_Get_Struct (self, struct device_t, d);
  return INT2NUM(d->descriptor->bcdDevice);
}

/*
* call-seq:
*   device.iManufacturer -> iManufacturer
*
* Get the index of the manufacturer string.
*
* Returns a +FixNum+ and never raises an exception.
*/
static VALUE cDevice_iManufacturer (VALUE self)
{
  struct device_t *d;

  Data_Get_Struct (self, struct device_t, d);
  return INT2NUM(d->descriptor->iManufacturer);
}

/*
* call-seq:
*   device.iProduct -> iProduct
*
* Get the index of the product string.
*
* Returns a +FixNum+ and never raises an exception.
*/
static VALUE cDevice_iProduct (VALUE self)
{
  struct device_t *d;

  Data_Get_Struct (self, struct device_t, d);
  return INT2NUM(d->descriptor->iProduct);
}

/*
* call-seq:
*   device.iSerialNumber -> iSerialNumber
*
* Get the index of the serial number string.
*
* Returns a +FixNum+ and never raises an exception.
*/
static VALUE cDevice_iSerialNumber (VALUE self)
{
  struct device_t *d;

  Data_Get_Struct (self, struct device_t, d);
  return INT2NUM(d->descriptor->iSerialNumber);
}

/*
* call-seq:
*   device.bNumConfigurations -> bNumConfigurations
*
* Get the number of configurations of the device.
*
* Returns a +FixNum+ and never raises an exception.
*/
static VALUE cDevice_bNumConfigurations (VALUE self)
{
  struct device_t *d;

  Data_Get_Struct (self, struct device_t, d);
  return INT2NUM(d->descriptor->bNumConfigurations);
}

/*
* call-seq:
*   device.get_active_config_descriptor -> Array<ConfigDescriptor>
*   device.active_config_descriptor -> Array<ConfigDescriptor>
*
* Get the USB configuration descriptor for the currently active configuration.
*
* Returns an array of +RibUSB::ConfigDescriptor+ .
*/
static VALUE cDevice_get_active_config_descriptor (VALUE self)
{
  struct device_t *d;
  struct libusb_config_descriptor *config;
  int res;

  Data_Get_Struct (self, struct device_t, d);
  res = libusb_get_active_config_descriptor( d->device, &config);
  if (res < 0)
    raise_error( res, "Failed to get config descriptor" );
  return cConfigDescriptor_new(config, self);
}

/*
* call-seq:
*   device.get_config_descriptor(config_index) -> Array<ConfigDescriptor>
*   device.config_descriptor(config_index) -> Array<ConfigDescriptor>
*
* Get a USB configuration descriptor based on its index.
*
* Returns an array of +RibUSB::ConfigDescriptor+ .
*/
static VALUE cDevice_get_config_descriptor (VALUE self, VALUE config_index)
{
  struct device_t *d;
  struct libusb_config_descriptor *config;
  int res;

  Data_Get_Struct (self, struct device_t, d);
  res = libusb_get_config_descriptor( d->device, NUM2INT(config_index), &config);
  if (res < 0)
    raise_error( res, "Failed to get config descriptor" );
  return cConfigDescriptor_new(config, self);
}

/*
* call-seq:
*   device.get_config_descriptor_by_value(config_index) -> Array<ConfigDescriptor>
*   device.config_descriptor_by_value(config_index) -> Array<ConfigDescriptor>
*
* Get a USB configuration descriptor with a specific bConfigurationValue.
*
* Returns an array of +RibUSB::ConfigDescriptor+ .
*/
static VALUE cDevice_get_config_descriptor_by_value (VALUE self, VALUE bConfigurationValue)
{
  struct device_t *d;
  struct libusb_config_descriptor *config;
  int res;

  Data_Get_Struct (self, struct device_t, d);
  res = libusb_get_config_descriptor_by_value( d->device, NUM2INT(bConfigurationValue), &config);
  if (res < 0)
    raise_error( res, "Failed to get config descriptor" );
  return cConfigDescriptor_new(config, self);
}


/******************************************************
* RibUSB::Transfer method definitions                *
******************************************************/

void cTransfer_free (struct transfer_t *t)
{
  libusb_free_transfer (t->transfer);
  if( t->buffer ) xfree (t->buffer);
  xfree (t);
}

/*
* call-seq:
*   transfer.submit -> nil
*
* Submit the asynchronous transfer.
*
* On success, returns +nil+, otherwise raises an exception and returns the _libusb_ error code (+FixNum+).
*/
static VALUE cTransfer_submit (VALUE self)
{
  struct transfer_t *t;
  int res;

  Data_Get_Struct (self, struct transfer_t, t);
  res = libusb_submit_transfer (t->transfer);
  if (res)
    raise_error( res, "Failed to submit asynchronous transfer" );
  return Qnil;
}

/*
* call-seq:
*   transfer.cancel -> nil
*
* Cancel the asynchronous transfer.
*
* On success, returns +nil+, otherwise raises an exception and returns the _libusb_ error code (+FixNum+).
*/
static VALUE cTransfer_cancel (VALUE self)
{
  struct transfer_t *t;
  int res;

  Data_Get_Struct (self, struct transfer_t, t);
  res = libusb_cancel_transfer (t->transfer);
  if (res)
    raise_error( res, "Failed to cancel asynchronous transfer" );
  return Qnil;
}

/*
* call-seq:
*   transfer.status -> status
*
* Retrieve the status of the asynchronous transfer.
*
* XXX describe status
*
* Use outside of an asynchronous transfer callback block leads to undefined behaviour.
*
* Returns a +Symbol+ and never raises an exception.
*/
static VALUE cTransfer_status (VALUE self)
{
  struct transfer_t *t;

  Data_Get_Struct (self, struct transfer_t, t);
  switch (t->transfer->status) {
  case LIBUSB_TRANSFER_COMPLETED:
    return ID2SYM(rb_intern (":completed"));
    break;
  case LIBUSB_TRANSFER_ERROR:
    return ID2SYM(rb_intern (":error"));
    break;
  case LIBUSB_TRANSFER_TIMED_OUT:
    return ID2SYM(rb_intern (":timed_out"));
    break;
  case LIBUSB_TRANSFER_CANCELLED:
    return ID2SYM(rb_intern (":cancelled"));
    break;
  case LIBUSB_TRANSFER_STALL:
    return ID2SYM(rb_intern (":stall"));
    break;
  case LIBUSB_TRANSFER_NO_DEVICE:
    return ID2SYM(rb_intern (":no_device"));
    break;
  case LIBUSB_TRANSFER_OVERFLOW:
    return ID2SYM(rb_intern (":overflow"));
    break;
  default:
    rb_raise (eError, "Invalid transfer status: %i.", t->transfer->status);
  }
}

/*
* call-seq:
*   transfer.result -> result
*
* Retrieve the result of the asynchronous transfer. For failed transfers
* an exception is raised.
*
* Use outside of an asynchronous transfer callback block leads to undefined behaviour.
*
* Returns the received data or the number of transferred bytes
* depending on the :dataIn / :dataOut parameter.
*/
static VALUE cTransfer_result (VALUE self)
{
  struct transfer_t *t;
  enum libusb_error err;

  Data_Get_Struct (self, struct transfer_t, t);
  switch (t->transfer->status) {
    case LIBUSB_TRANSFER_ERROR: err = LIBUSB_ERROR_IO; break;
    case LIBUSB_TRANSFER_TIMED_OUT: err = LIBUSB_ERROR_TIMEOUT; break;
    case LIBUSB_TRANSFER_CANCELLED: err = LIBUSB_ERROR_INTERRUPTED; break;
    case LIBUSB_TRANSFER_STALL: err = LIBUSB_ERROR_PIPE; break;
    case LIBUSB_TRANSFER_NO_DEVICE: err = LIBUSB_ERROR_NO_DEVICE; break;
    case LIBUSB_TRANSFER_OVERFLOW: err = LIBUSB_ERROR_OVERFLOW; break;
    default: err = LIBUSB_ERROR_OTHER;
  }

  if( t->transfer->status != LIBUSB_TRANSFER_COMPLETED )
    raise_error( err, "Error while asynchronous transfer" );

  if( t->transfer->type == LIBUSB_TRANSFER_TYPE_CONTROL ){
    /* control transfer */
    if( t->foreign_data_in ){
      memcpy(t->foreign_data_in_ptr, libusb_control_transfer_get_data(t->transfer), t->transfer->actual_length);
      return INT2NUM(t->transfer->actual_length);
    }else{
      return rb_str_new ((char *) libusb_control_transfer_get_data(t->transfer), t->transfer->actual_length);
    }
  }else{
    if( t->foreign_data_in ){
      return INT2NUM(t->transfer->actual_length);
    }else{
      return rb_str_new ((char *) t->buffer, t->transfer->actual_length);
    }
  }
}



/******************************************************
* RibUSB::ConfigDescriptor method definitions        *
******************************************************/

void cConfigDescriptor_free (struct config_descriptor_t *c)
{
  libusb_free_config_descriptor (c->descriptor);

  xfree (c);
}

static VALUE cConfigDescriptor_new (struct libusb_config_descriptor *descriptor, VALUE device)
{
  struct config_descriptor_t *d;
  VALUE object;

  d = ALLOC(struct config_descriptor_t);
  d->descriptor = descriptor;
  object = Data_Wrap_Struct (ConfigDescriptor, NULL, cConfigDescriptor_free, d);
  rb_iv_set(object, "@device", device);
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
*   descriptor.interfaces -> interfaces
*
* Retrieve the list of interfaces in this configuration.
*
* Returns an array of +RibUSB::Interface+ and never raises an exception.
*/
static VALUE cConfigDescriptor_interfaces (VALUE self)
{
  struct config_descriptor_t *d;
  VALUE array;
  int n_array, i;

  Data_Get_Struct (self, struct config_descriptor_t, d);

  n_array = d->descriptor->bNumInterfaces;
  array = rb_ary_new2 (n_array);

  for (i = 0; i < n_array; i ++)
    rb_ary_store (array, i, cInterface_new (d->descriptor->interface + i, self));

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
  return rb_str_new((char *) d->descriptor->extra, d->descriptor->extra_length);
}



/******************************************************
* RibUSB::Interface method definitions               *
******************************************************/

static VALUE cInterface_new (const struct libusb_interface *interface, VALUE config_descriptor)
{
  struct interface_t *i;
  VALUE object;

  i = ALLOC(struct interface_t);
  i->interface = interface;
  object = Data_Wrap_Struct (Interface, NULL, xfree, i);
  rb_iv_set(object, "@configuration", config_descriptor);
  rb_obj_call_init (object, 0, 0);
  return object;
}

/*
* call-seq:
*   interface.alt_settings -> alt_settings
*
* Retrieve the list of interface descriptors.
*
* Returns an array of +RibUSB::Interface+ and never raises an exception.
*/
static VALUE cInterface_alt_settings (VALUE self)
{
  struct interface_t *d;
  VALUE array;
  int n_array, i;

  Data_Get_Struct (self, struct interface_t, d);

  n_array = d->interface->num_altsetting;
  array = rb_ary_new2 (n_array);

  for (i = 0; i < n_array; i ++)
    rb_ary_store (array, i, cInterfaceDescriptor_new (d->interface->altsetting + i, self));

  return array;
}



/******************************************************
* RibUSB::InterfaceDescriptor method definitions     *
******************************************************/

static VALUE cInterfaceDescriptor_new (const struct libusb_interface_descriptor *descriptor, VALUE interface)
{
  struct interface_descriptor_t *d;
  VALUE object;

  d = ALLOC(struct interface_descriptor_t);
  d->descriptor = descriptor;
  object = Data_Wrap_Struct (InterfaceDescriptor, NULL, xfree, d);
  rb_iv_set(object, "@interface", interface);
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
*   descriptor.endpoints -> endpoints
*
* Retrieve the list of endpoints in this interface.
*
* Returns an array of +RibUSB::Endpoint+ and never raises an exception.
*/
static VALUE cInterfaceDescriptor_endpoints (VALUE self)
{
  struct interface_descriptor_t *d;
  VALUE array;
  int n_array, i;

  Data_Get_Struct (self, struct interface_descriptor_t, d);

  n_array = d->descriptor->bNumEndpoints;
  array = rb_ary_new2 (n_array);

  for (i = 0; i < n_array; i ++)
    rb_ary_store (array, i, cEndpointDescriptor_new (d->descriptor->endpoint + i, self));

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
  return rb_str_new((char *) d->descriptor->extra, d->descriptor->extra_length);
}



/******************************************************
* RibUSB::EndpointDescriptor method definitions      *
******************************************************/

static VALUE cEndpointDescriptor_new (const struct libusb_endpoint_descriptor *descriptor, VALUE interface_descriptor)
{
  struct endpoint_descriptor_t *d;
  VALUE object;

  d = ALLOC(struct endpoint_descriptor_t);
  d->descriptor = descriptor;
  object = Data_Wrap_Struct (EndpointDescriptor, NULL, xfree, d);
  rb_iv_set(object, "@interface_descriptor", interface_descriptor);
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
  return rb_str_new((char *) d->descriptor->extra, d->descriptor->extra_length);
}



/******************************************************
* RibUSB -- an interface to _libusb_, API version 1.0
******************************************************/
void Init_ribusb_ext()
{
  RibUSB = rb_define_module ("RibUSB");

  /* Library version */
  rb_define_const( RibUSB, "VERSION", rb_str_new2(VERSION) );

  /* RibUSB::Context -- a class for _libusb_ bus-handling sessions */
  Context = rb_define_class_under (RibUSB, "Context", rb_cObject);
  rb_define_singleton_method (Context, "new", cContext_new, 0);
  rb_define_method (Context, "set_debug", cContext_set_debug, 1);
  rb_define_alias (Context, "debug=", "set_debug");
  rb_define_method (Context, "find", cContext_find, -1);
  rb_define_method (Context, "handle_events", cContext_handle_events, 0);

  /* RibUSB::Device -- a class for individual USB devices accessed through _libusb_ */
  Device = rb_define_class_under (RibUSB, "Device", rb_cObject);
  rb_define_method (Device, "close", cDevice_close, 0);
  rb_define_method (Device, "get_bus_number", cDevice_get_bus_number, 0);
  rb_define_alias (Device, "bus_number", "get_bus_number");
  rb_define_method (Device, "get_device_address", cDevice_get_device_address, 0);
  rb_define_alias (Device, "device_address", "get_device_address");
  rb_define_method (Device, "get_max_packet_size", cDevice_get_max_packet_size, 1);
  rb_define_alias (Device, "max_packet_size", "get_max_packet_size");
  rb_define_method (Device, "get_configuration", cDevice_get_configuration, 0);
  rb_define_alias (Device, "configuration", "get_configuration");
  rb_define_method (Device, "set_configuration", cDevice_set_configuration, 1);
  rb_define_alias (Device, "configuration=", "set_configuration");
  rb_define_method (Device, "claim_interface", cDevice_claim_interface, 1);
  rb_define_method (Device, "release_interface", cDevice_release_interface, 1);
  rb_define_method (Device, "set_interface_alt_setting", cDevice_set_interface_alt_setting, 2);
  rb_define_method (Device, "clear_halt", cDevice_clear_halt, 1);
  rb_define_method (Device, "reset_device", cDevice_reset_device, 0);
  rb_define_method (Device, "kernel_driver_active?", cDevice_kernel_driver_activeQ, 1);
  rb_define_method (Device, "detach_kernel_driver", cDevice_detach_kernel_driver, 1);
  rb_define_method (Device, "attach_kernel_driver", cDevice_attach_kernel_driver, 1);
  rb_define_method (Device, "get_string_descriptor_ascii", cDevice_get_string_descriptor_ascii, 1);
  rb_define_alias (Device, "string_descriptor_ascii", "get_string_descriptor_ascii");
  rb_define_method (Device, "get_string_descriptor", cDevice_get_string_descriptor, 2);
  rb_define_alias (Device, "string_descriptor", "get_string_descriptor");
  rb_define_method (Device, "control_transfer", cDevice_control_transfer, 1);
  rb_define_method (Device, "bulk_transfer", cDevice_bulk_transfer, 1);
  rb_define_method (Device, "interrupt_transfer", cDevice_interrupt_transfer, 1);

  rb_define_method (Device, "bcdUSB", cDevice_bcdUSB, 0);
  rb_define_method (Device, "bDeviceClass", cDevice_bDeviceClass, 0);
  rb_define_method (Device, "bDeviceSubClass", cDevice_bDeviceSubClass, 0);
  rb_define_method (Device, "bDeviceProtocol", cDevice_bDeviceProtocol, 0);
  rb_define_method (Device, "bMaxPacketSize0", cDevice_bMaxPacketSize0, 0);
  rb_define_method (Device, "idVendor", cDevice_idVendor, 0);
  rb_define_method (Device, "idProduct", cDevice_idProduct, 0);
  rb_define_method (Device, "bcdDevice", cDevice_bcdDevice, 0);
  rb_define_method (Device, "iManufacturer", cDevice_iManufacturer, 0);
  rb_define_method (Device, "iProduct", cDevice_iProduct, 0);
  rb_define_method (Device, "iSerialNumber", cDevice_iSerialNumber, 0);
  rb_define_method (Device, "bNumConfigurations", cDevice_bNumConfigurations, 0);
  rb_define_method (Device, "get_active_config_descriptor", cDevice_get_active_config_descriptor, 0);
  rb_define_alias (Device, "active_config_descriptor", "get_active_config_descriptor");
  rb_define_method (Device, "get_config_descriptor", cDevice_get_config_descriptor, 1);
  rb_define_alias (Device, "config_descriptor", "get_config_descriptor");
  rb_define_method (Device, "get_config_descriptor_by_value", cDevice_get_config_descriptor_by_value, 1);
  rb_define_alias (Device, "config_descriptor_by_value", "get_config_descriptor_by_value");
  /* The Context the device belongs to. */
  rb_define_attr (Device, "context", 1, 0);

  /* RibUSB::Transfer -- a class for asynchronous USB transfers */
  Transfer = rb_define_class_under (RibUSB, "Transfer", rb_cObject);
  rb_define_method (Transfer, "submit", cTransfer_submit, 0);
  rb_define_method (Transfer, "cancel", cTransfer_cancel, 0);
  rb_define_method (Transfer, "status", cTransfer_status, 0);
  rb_define_method (Transfer, "result", cTransfer_result, 0);

  /* RibUSB::ConfigDescriptor -- a class for USB config descriptors */
  ConfigDescriptor = rb_define_class_under (RibUSB, "ConfigDescriptor", rb_cObject);
  rb_define_method (ConfigDescriptor, "bLength", cConfigDescriptor_bLength, 0);
  rb_define_method (ConfigDescriptor, "bDescriptorType", cConfigDescriptor_bDescriptorType, 0);
  rb_define_method (ConfigDescriptor, "wTotalLength", cConfigDescriptor_wTotalLength, 0);
  rb_define_method (ConfigDescriptor, "bNumInterfaces", cConfigDescriptor_bNumInterfaces, 0);
  rb_define_method (ConfigDescriptor, "bConfigurationValue", cConfigDescriptor_bConfigurationValue, 0);
  rb_define_method (ConfigDescriptor, "iConfiguration", cConfigDescriptor_iConfiguration, 0);
  rb_define_method (ConfigDescriptor, "bmAttributes", cConfigDescriptor_bmAttributes, 0);
  rb_define_method (ConfigDescriptor, "maxPower", cConfigDescriptor_maxPower, 0);
  rb_define_method (ConfigDescriptor, "interfaces", cConfigDescriptor_interfaces, 0);
  rb_define_method (ConfigDescriptor, "extra", cConfigDescriptor_extra, 0);
  /* The Device the configuration belongs to. */
  rb_define_attr (ConfigDescriptor, "device", 1, 0);

  /* RibUSB::Interface -- a class for USB interfaces */
  Interface = rb_define_class_under (RibUSB, "Interface", rb_cObject);
  rb_define_method (Interface, "alt_settings", cInterface_alt_settings, 0);
  /* The ConfigDescriptor the interface belongs to. */
  rb_define_attr (Interface, "configuration", 1, 0);

  /* RibUSB::InterfaceDescriptor -- a class for USB interface descriptors */
  InterfaceDescriptor = rb_define_class_under (RibUSB, "InterfaceDescriptor", rb_cObject);
  rb_define_method (InterfaceDescriptor, "bLength", cInterfaceDescriptor_bLength, 0);
  rb_define_method (InterfaceDescriptor, "bDescriptorType", cInterfaceDescriptor_bDescriptorType, 0);
  rb_define_method (InterfaceDescriptor, "bInterfaceNumber", cInterfaceDescriptor_bInterfaceNumber, 0);
  rb_define_method (InterfaceDescriptor, "bAlternateSetting", cInterfaceDescriptor_bAlternateSetting, 0);
  rb_define_method (InterfaceDescriptor, "bNumEndpoints", cInterfaceDescriptor_bNumEndpoints, 0);
  rb_define_method (InterfaceDescriptor, "bInterfaceClass", cInterfaceDescriptor_bInterfaceClass, 0);
  rb_define_method (InterfaceDescriptor, "bInterfaceSubClass", cInterfaceDescriptor_bInterfaceSubClass, 0);
  rb_define_method (InterfaceDescriptor, "bInterfaceProtocol", cInterfaceDescriptor_bInterfaceProtocol, 0);
  rb_define_method (InterfaceDescriptor, "iInterface", cInterfaceDescriptor_iInterface, 0);
  rb_define_method (InterfaceDescriptor, "endpoints", cInterfaceDescriptor_endpoints, 0);
  rb_define_method (InterfaceDescriptor, "extra", cInterfaceDescriptor_extra, 0);
  /* The Interface the interface description belongs to. */
  rb_define_attr (InterfaceDescriptor, "interface", 1, 0);

  /* RibUSB::EndpointDescriptor -- a class for USB endpoint descriptors */
  EndpointDescriptor = rb_define_class_under (RibUSB, "EndpointDescriptor", rb_cObject);
  rb_define_method (EndpointDescriptor, "bLength", cEndpointDescriptor_bLength, 0);
  rb_define_method (EndpointDescriptor, "bDescriptorType", cEndpointDescriptor_bDescriptorType, 0);
  rb_define_method (EndpointDescriptor, "bEndpointAddress", cEndpointDescriptor_bEndpointAddress, 0);
  rb_define_method (EndpointDescriptor, "bmAttributes", cEndpointDescriptor_bmAttributes, 0);
  rb_define_method (EndpointDescriptor, "wMaxPacketSize", cEndpointDescriptor_wMaxPacketSize, 0);
  rb_define_method (EndpointDescriptor, "bInterval", cEndpointDescriptor_bInterval, 0);
  rb_define_method (EndpointDescriptor, "bRefresh", cEndpointDescriptor_bRefresh, 0);
  rb_define_method (EndpointDescriptor, "bSynchAddress", cEndpointDescriptor_bSynchAddress, 0);
  rb_define_method (EndpointDescriptor, "extra", cEndpointDescriptor_extra, 0);
  /* The InterfaceDescriptor the endpoint belongs to. */
  rb_define_attr (EndpointDescriptor, "interface_descriptor", 1, 0);


  #define RIBUSB_DEFINE_CONST(constant) \
    rb_define_const(RibUSB, #constant, INT2NUM(constant))

  RIBUSB_DEFINE_CONST( LIBUSB_CLASS_PER_INTERFACE );
  RIBUSB_DEFINE_CONST( LIBUSB_CLASS_AUDIO );
  RIBUSB_DEFINE_CONST( LIBUSB_CLASS_COMM );
  RIBUSB_DEFINE_CONST( LIBUSB_CLASS_HID );
  RIBUSB_DEFINE_CONST( LIBUSB_CLASS_PRINTER );
  RIBUSB_DEFINE_CONST( LIBUSB_CLASS_PTP );
  RIBUSB_DEFINE_CONST( LIBUSB_CLASS_MASS_STORAGE );
  RIBUSB_DEFINE_CONST( LIBUSB_CLASS_HUB );
  RIBUSB_DEFINE_CONST( LIBUSB_CLASS_DATA );
  RIBUSB_DEFINE_CONST( LIBUSB_CLASS_WIRELESS );
  RIBUSB_DEFINE_CONST( LIBUSB_CLASS_APPLICATION );
  RIBUSB_DEFINE_CONST( LIBUSB_CLASS_VENDOR_SPEC );

  RIBUSB_DEFINE_CONST( LIBUSB_DT_DEVICE );
  RIBUSB_DEFINE_CONST( LIBUSB_DT_CONFIG );
  RIBUSB_DEFINE_CONST( LIBUSB_DT_STRING );
  RIBUSB_DEFINE_CONST( LIBUSB_DT_INTERFACE );
  RIBUSB_DEFINE_CONST( LIBUSB_DT_ENDPOINT );
  RIBUSB_DEFINE_CONST( LIBUSB_DT_HID );
  RIBUSB_DEFINE_CONST( LIBUSB_DT_REPORT );
  RIBUSB_DEFINE_CONST( LIBUSB_DT_PHYSICAL );
  RIBUSB_DEFINE_CONST( LIBUSB_DT_HUB );

  RIBUSB_DEFINE_CONST( LIBUSB_DT_DEVICE_SIZE );
  RIBUSB_DEFINE_CONST( LIBUSB_DT_CONFIG_SIZE );
  RIBUSB_DEFINE_CONST( LIBUSB_DT_INTERFACE_SIZE );
  RIBUSB_DEFINE_CONST( LIBUSB_DT_ENDPOINT_SIZE );
  RIBUSB_DEFINE_CONST( LIBUSB_DT_ENDPOINT_AUDIO_SIZE );
  RIBUSB_DEFINE_CONST( LIBUSB_DT_HUB_NONVAR_SIZE );

  RIBUSB_DEFINE_CONST( LIBUSB_ENDPOINT_ADDRESS_MASK );

  RIBUSB_DEFINE_CONST( LIBUSB_ENDPOINT_DIR_MASK );
  RIBUSB_DEFINE_CONST( LIBUSB_ENDPOINT_IN );
  RIBUSB_DEFINE_CONST( LIBUSB_ENDPOINT_OUT );

  RIBUSB_DEFINE_CONST( LIBUSB_TRANSFER_TYPE_MASK );
  RIBUSB_DEFINE_CONST( LIBUSB_TRANSFER_TYPE_CONTROL );
  RIBUSB_DEFINE_CONST( LIBUSB_TRANSFER_TYPE_ISOCHRONOUS );
  RIBUSB_DEFINE_CONST( LIBUSB_TRANSFER_TYPE_BULK );
  RIBUSB_DEFINE_CONST( LIBUSB_TRANSFER_TYPE_INTERRUPT );

  RIBUSB_DEFINE_CONST( LIBUSB_REQUEST_GET_STATUS );
  RIBUSB_DEFINE_CONST( LIBUSB_REQUEST_CLEAR_FEATURE );
  RIBUSB_DEFINE_CONST( LIBUSB_REQUEST_SET_FEATURE );
  RIBUSB_DEFINE_CONST( LIBUSB_REQUEST_SET_ADDRESS );
  RIBUSB_DEFINE_CONST( LIBUSB_REQUEST_GET_DESCRIPTOR );
  RIBUSB_DEFINE_CONST( LIBUSB_REQUEST_SET_DESCRIPTOR );
  RIBUSB_DEFINE_CONST( LIBUSB_REQUEST_GET_CONFIGURATION );
  RIBUSB_DEFINE_CONST( LIBUSB_REQUEST_SET_CONFIGURATION );
  RIBUSB_DEFINE_CONST( LIBUSB_REQUEST_GET_INTERFACE );
  RIBUSB_DEFINE_CONST( LIBUSB_REQUEST_SET_INTERFACE );
  RIBUSB_DEFINE_CONST( LIBUSB_REQUEST_SYNCH_FRAME );
  RIBUSB_DEFINE_CONST( LIBUSB_REQUEST_TYPE_STANDARD );
  RIBUSB_DEFINE_CONST( LIBUSB_REQUEST_TYPE_CLASS );
  RIBUSB_DEFINE_CONST( LIBUSB_REQUEST_TYPE_VENDOR );
  RIBUSB_DEFINE_CONST( LIBUSB_REQUEST_TYPE_RESERVED );
  RIBUSB_DEFINE_CONST( LIBUSB_RECIPIENT_DEVICE );
  RIBUSB_DEFINE_CONST( LIBUSB_RECIPIENT_INTERFACE );
  RIBUSB_DEFINE_CONST( LIBUSB_RECIPIENT_ENDPOINT );
  RIBUSB_DEFINE_CONST( LIBUSB_RECIPIENT_OTHER );

  RIBUSB_DEFINE_CONST( LIBUSB_ISO_SYNC_TYPE_MASK );
  RIBUSB_DEFINE_CONST( LIBUSB_ISO_SYNC_TYPE_NONE );
  RIBUSB_DEFINE_CONST( LIBUSB_ISO_SYNC_TYPE_ASYNC );
  RIBUSB_DEFINE_CONST( LIBUSB_ISO_SYNC_TYPE_ADAPTIVE );
  RIBUSB_DEFINE_CONST( LIBUSB_ISO_SYNC_TYPE_SYNC );

  RIBUSB_DEFINE_CONST( LIBUSB_ISO_USAGE_TYPE_MASK );
  RIBUSB_DEFINE_CONST( LIBUSB_ISO_USAGE_TYPE_DATA );
  RIBUSB_DEFINE_CONST( LIBUSB_ISO_USAGE_TYPE_FEEDBACK );
  RIBUSB_DEFINE_CONST( LIBUSB_ISO_USAGE_TYPE_IMPLICIT );

  eError = rb_define_class_under(RibUSB, "Error", rb_eRuntimeError);
  #define DEFINE_ERROR_CLASS(name, desc) { e##name = rb_define_class_under(RibUSB, #name, eError); }
  FOREACH_ERROR_CODE(DEFINE_ERROR_CLASS);

}
