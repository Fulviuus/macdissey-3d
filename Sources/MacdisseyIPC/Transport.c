#include "MacdisseyIPC.h"
#include <bsm/libbsm.h>
#include <mach/mach.h>
#include <pthread.h>
#include <servers/bootstrap.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define MDS_MAGIC 0x4d445331
#define MDS_ICC_MAX 65536
typedef struct {
  mach_msg_header_t header;
  mach_msg_body_t body;
  mach_msg_port_descriptor_t surfaces[2];
  uint32_t reserved;
  uint32_t version, command, width, height;
  uint64_t session, sequence;
  char name[128];
} RequestWire;
typedef struct {
  mach_msg_header_t header;
  int32_t status;
  uint32_t reserved;
  MDSInfo info;
  char message[256];
  uint32_t icc_size;
  uint8_t icc[MDS_ICC_MAX];
} ReplyWire;
struct MDSHost {
  mach_port_t port;
};
struct MDSClient {
  mach_port_t server;
  CFDataRef icc;
  char error[256];
};
struct MDSRequest {
  RequestWire wire;
  pid_t pid;
  IOSurfaceRef left, right;
};
static char service[128];
static pthread_once_t service_once = PTHREAD_ONCE_INIT;
static void make_service(void) {
  snprintf(service, sizeof(service), "io.github.fulviuus.macdissey.direct.%u", getuid());
}
const char *mds_service_name(void) {
  pthread_once(&service_once, make_service);
  return service;
}
static int receive(mach_port_t port, void *buffer, size_t capacity, uint32_t timeout) {
  mach_msg_header_t *h = buffer;
  return mach_msg(h,
                  MACH_RCV_MSG | MACH_RCV_TIMEOUT |
                      MACH_RCV_TRAILER_TYPE(MACH_MSG_TRAILER_FORMAT_0) |
                      MACH_RCV_TRAILER_ELEMENTS(MACH_RCV_TRAILER_AUDIT),
                  0, (mach_msg_size_t)capacity, port, timeout, MACH_PORT_NULL);
}
static const mach_msg_audit_trailer_t *message_audit(const mach_msg_header_t *h) {
  const mach_msg_audit_trailer_t *t = (const void *)((const char *)h + ((h->msgh_size + 3) & ~3u));
  return t->msgh_trailer_type == MACH_MSG_TRAILER_FORMAT_0 && t->msgh_trailer_size >= sizeof(*t)
             ? t
             : NULL;
}
MDSHost *mds_host_create(const char *name) {
  if (!name || !name[0] || strlen(name) >= BOOTSTRAP_MAX_NAME_LEN)
    return NULL;
  MDSHost *host = calloc(1, sizeof(*host));
  if (!host)
    return NULL;
  if (mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &host->port) != KERN_SUCCESS ||
      mach_port_insert_right(mach_task_self(), host->port, host->port, MACH_MSG_TYPE_MAKE_SEND) !=
          KERN_SUCCESS) {
    mds_host_destroy(host);
    return NULL;
  }
  // Public legacy registration lets an ordinary running app advertise a port
  // without installing a launch agent. It exists only for this process lifetime.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  kern_return_t result = bootstrap_register(bootstrap_port, (char *)name, host->port);
#pragma clang diagnostic pop
  if (result != KERN_SUCCESS) {
    mds_host_destroy(host);
    return NULL;
  }
  return host;
}
void mds_host_destroy(MDSHost *host) {
  if (!host)
    return;
  if (host->port) {
    mach_port_deallocate(mach_task_self(), host->port);
    mach_port_mod_refs(mach_task_self(), host->port, MACH_PORT_RIGHT_RECEIVE, -1);
  }
  free(host);
}
uint32_t mds_host_port(MDSHost *host) { return host->port; }
static void dispose(MDSRequest *request) {
  if (request->left)
    CFRelease(request->left);
  if (request->right)
    CFRelease(request->right);
  mach_msg_destroy(&request->wire.header);
  free(request);
}
MDSRequest *mds_host_receive(MDSHost *host, uint32_t timeout) {
  struct {
    RequestWire wire;
    mach_msg_max_trailer_t trailer;
  } incoming = {0};
  if (!host || receive(host->port, &incoming, sizeof(incoming), timeout) != MACH_MSG_SUCCESS)
    return NULL;
  RequestWire *w = &incoming.wire;
  const mach_msg_audit_trailer_t *t = message_audit(&w->header);
  if (w->header.msgh_size != sizeof(*w) || w->header.msgh_id != MDS_MAGIC || !t ||
      audit_token_to_euid(t->msgh_audit) != getuid() || !w->header.msgh_remote_port ||
      MACH_MSGH_BITS_REMOTE(w->header.msgh_bits) != MACH_MSG_TYPE_PORT_SEND_ONCE) {
    mach_msg_destroy(&w->header);
    return NULL;
  }
  const int frame = w->command == MDS_FRAME;
  if ((frame &&
       (!(w->header.msgh_bits & MACH_MSGH_BITS_COMPLEX) || w->body.msgh_descriptor_count != 2 ||
        w->surfaces[0].type != MACH_MSG_PORT_DESCRIPTOR ||
        w->surfaces[1].type != MACH_MSG_PORT_DESCRIPTOR)) ||
      (!frame && (w->header.msgh_bits & MACH_MSGH_BITS_COMPLEX))) {
    mach_msg_destroy(&w->header);
    return NULL;
  }
  MDSRequest *r = calloc(1, sizeof(*r));
  if (!r) {
    mach_msg_destroy(&w->header);
    return NULL;
  }
  r->wire = *w;
  r->wire.name[sizeof(r->wire.name) - 1] = 0;
  r->pid = audit_token_to_pid(t->msgh_audit);
  if (frame) {
    r->left = IOSurfaceLookupFromMachPort(w->surfaces[0].name);
    r->right = IOSurfaceLookupFromMachPort(w->surfaces[1].name);
  }
  if (w->version != 1) {
    mds_request_reply(r, MDS_VERSION, NULL, NULL, "Unsupported direct-stereo protocol version.");
    return NULL;
  }
  return r;
}
uint32_t mds_request_command(const MDSRequest *r) { return r->wire.command; }
uint32_t mds_request_width(const MDSRequest *r) { return r->wire.width; }
uint32_t mds_request_height(const MDSRequest *r) { return r->wire.height; }
uint64_t mds_request_session(const MDSRequest *r) { return r->wire.session; }
uint64_t mds_request_sequence(const MDSRequest *r) { return r->wire.sequence; }
pid_t mds_request_pid(const MDSRequest *r) { return r->pid; }
const char *mds_request_name(const MDSRequest *r) { return r->wire.name; }
IOSurfaceRef mds_request_left(const MDSRequest *r) { return r->left; }
IOSurfaceRef mds_request_right(const MDSRequest *r) { return r->right; }
int mds_request_reply(MDSRequest *r, int status, const MDSInfo *info, CFDataRef icc,
                      const char *message) {
  ReplyWire reply = {0};
  reply.header.msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_MOVE_SEND_ONCE, 0);
  reply.header.msgh_remote_port = r->wire.header.msgh_remote_port;
  reply.header.msgh_id = MDS_MAGIC;
  reply.status = status;
  if (info)
    reply.info = *info;
  if (message)
    snprintf(reply.message, sizeof(reply.message), "%s", message);
  const CFIndex n = icc ? CFDataGetLength(icc) : 0;
  if (n > MDS_ICC_MAX) {
    reply.status = MDS_UNAVAILABLE;
    snprintf(reply.message, sizeof(reply.message),
             "Display colour profile exceeds the protocol limit.");
  } else if (n > 0) {
    reply.icc_size = (uint32_t)n;
    memcpy(reply.icc, CFDataGetBytePtr(icc), (size_t)n);
  }
  reply.header.msgh_size = (mach_msg_size_t)(offsetof(ReplyWire, icc) + reply.icc_size);
  int result = mach_msg(&reply.header, MACH_SEND_MSG | MACH_SEND_TIMEOUT, reply.header.msgh_size, 0,
                        MACH_PORT_NULL, 100, MACH_PORT_NULL);
  r->wire.header.msgh_remote_port = MACH_PORT_NULL;
  if (result != MACH_MSG_SUCCESS)
    mach_msg_destroy(&reply.header);
  dispose(r);
  return result == MACH_MSG_SUCCESS;
}
MDSClient *mds_client_create(const char *name) {
  if (!name || !name[0] || strlen(name) >= BOOTSTRAP_MAX_NAME_LEN)
    return NULL;
  MDSClient *client = calloc(1, sizeof(*client));
  if (!client)
    return NULL;
  if (bootstrap_look_up(bootstrap_port, name, &client->server) != KERN_SUCCESS) {
    free(client);
    return NULL;
  }
  return client;
}
void mds_client_destroy(MDSClient *c) {
  if (!c)
    return;
  if (c->server)
    mach_port_deallocate(mach_task_self(), c->server);
  if (c->icc)
    CFRelease(c->icc);
  free(c);
}
int mds_surface_valid(IOSurfaceRef s, uint32_t width, uint32_t height) {
  if (!s || width < 2 || width > 3840 || height < 1 || height > 2160 ||
      IOSurfaceGetPlaneCount(s) != 0 || IOSurfaceGetWidth(s) != width ||
      IOSurfaceGetHeight(s) != height || IOSurfaceGetPixelFormat(s) != 0x42475241 ||
      IOSurfaceGetBytesPerElement(s) != 4 || IOSurfaceGetElementWidth(s) != 1 ||
      IOSurfaceGetElementHeight(s) != 1)
    return 0;
  size_t stride = IOSurfaceGetBytesPerRow(s);
  return IOSurfaceGetAllocSize(s) <= 64 * 1024 * 1024 && stride >= (size_t)width * 4 &&
         stride <= (size_t)width * 4 + 4096 && stride <= SIZE_MAX / height &&
         IOSurfaceGetAllocSize(s) >= stride * (height - 1) + (size_t)width * 4;
}
int mds_client_exchange(MDSClient *c, uint32_t command, uint64_t session, uint64_t sequence,
                        uint32_t width, uint32_t height, const char *label, IOSurfaceRef left,
                        IOSurfaceRef right, uint32_t timeout, MDSInfo *info) {
  if (!c)
    return MDS_TRANSPORT;
  c->error[0] = 0;
  mach_port_t response = MACH_PORT_NULL;
  if (mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &response) != KERN_SUCCESS)
    return MDS_TRANSPORT;
  RequestWire request = {0};
  request.header.msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, MACH_MSG_TYPE_MAKE_SEND_ONCE);
  request.header.msgh_remote_port = c->server;
  request.header.msgh_local_port = response;
  request.header.msgh_id = MDS_MAGIC;
  request.header.msgh_size = sizeof(request);
  request.version = 1;
  request.command = command;
  request.session = session;
  request.sequence = sequence;
  request.width = width;
  request.height = height;
  if (label)
    snprintf(request.name, sizeof(request.name), "%s", label);
  if (command == MDS_FRAME) {
    if (!mds_surface_valid(left, width, height) || !mds_surface_valid(right, width, height)) {
      mach_port_mod_refs(mach_task_self(), response, MACH_PORT_RIGHT_RECEIVE, -1);
      return MDS_INVALID;
    }
    request.header.msgh_bits |= MACH_MSGH_BITS_COMPLEX;
    request.body.msgh_descriptor_count = 2;
    request.surfaces[0].name = IOSurfaceCreateMachPort(left);
    request.surfaces[1].name = IOSurfaceCreateMachPort(right);
    for (int i = 0; i < 2; i++) {
      request.surfaces[i].disposition = MACH_MSG_TYPE_COPY_SEND;
      request.surfaces[i].type = MACH_MSG_PORT_DESCRIPTOR;
    }
  }
  int result = mach_msg(&request.header, MACH_SEND_MSG | MACH_SEND_TIMEOUT, sizeof(request), 0,
                        MACH_PORT_NULL, timeout, MACH_PORT_NULL);
  if (command == MDS_FRAME)
    for (int i = 0; i < 2; i++)
      if (request.surfaces[i].name)
        mach_port_deallocate(mach_task_self(), request.surfaces[i].name);
  if (result != MACH_MSG_SUCCESS) {
    mach_port_mod_refs(mach_task_self(), response, MACH_PORT_RIGHT_RECEIVE, -1);
    return MDS_TRANSPORT;
  }
  struct {
    ReplyWire wire;
    mach_msg_max_trailer_t trailer;
  } received = {0};
  result = receive(response, &received, sizeof(received), timeout);
  mach_port_mod_refs(mach_task_self(), response, MACH_PORT_RIGHT_RECEIVE, -1);
  if (result != MACH_MSG_SUCCESS)
    return result == MACH_RCV_TIMED_OUT ? MDS_TIMEOUT : MDS_TRANSPORT;
  ReplyWire *r = &received.wire;
  const mach_msg_audit_trailer_t *t = message_audit(&r->header);
  if (r->header.msgh_bits & MACH_MSGH_BITS_COMPLEX || r->header.msgh_id != MDS_MAGIC ||
      r->header.msgh_size < offsetof(ReplyWire, icc) || r->icc_size > MDS_ICC_MAX ||
      r->header.msgh_size != offsetof(ReplyWire, icc) + r->icc_size || !t ||
      audit_token_to_euid(t->msgh_audit) != getuid()) {
    mach_msg_destroy(&r->header);
    return MDS_TRANSPORT;
  }
  if (info)
    *info = r->info;
  snprintf(c->error, sizeof(c->error), "%.*s", (int)sizeof(r->message) - 1, r->message);
  if (command == MDS_BEGIN && r->status == MDS_OK) {
    if (c->icc)
      CFRelease(c->icc);
    c->icc = r->icc_size ? CFDataCreate(NULL, r->icc, r->icc_size) : NULL;
  }
  int status = r->status;
  mach_msg_destroy(&r->header);
  return status;
}
CFDataRef mds_client_copy_icc(MDSClient *c) { return c->icc ? CFRetain(c->icc) : NULL; }
const char *mds_client_error(MDSClient *c) { return c->error; }
