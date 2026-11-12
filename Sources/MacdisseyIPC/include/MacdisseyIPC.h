#ifndef MACDISSEY_IPC_H
#define MACDISSEY_IPC_H
#include <CoreFoundation/CoreFoundation.h>
#include <IOSurface/IOSurfaceRef.h>
#include <stdint.h>
#include <sys/types.h>
#ifdef __cplusplus
extern "C" {
#endif
enum { MDS_BEGIN = 1, MDS_FRAME = 2, MDS_PING = 3, MDS_END = 4 };
enum {
  MDS_OK = 0,
  MDS_DROPPED = 1,
  MDS_BUSY = 2,
  MDS_INVALID = 3,
  MDS_UNAVAILABLE = 4,
  MDS_STOPPED = 5,
  MDS_VERSION = 6,
  MDS_TRANSPORT = -1,
  MDS_TIMEOUT = -2
};
typedef struct MDSHost MDSHost;
typedef struct MDSClient MDSClient;
typedef struct MDSRequest MDSRequest;
typedef struct {
  uint64_t session, sequence;
  uint32_t output_width, output_height, tracked, reserved;
  double refresh_rate, timestamp;
  // Measured display-space midpoint; optical prediction remains in the host.
  // IPD is the rolling interocular mean, in millimetres.
  float viewer_x_cm, viewer_y_cm, viewer_z_cm, ipd_mm;
  float display_width_mm, display_height_mm;
} MDSInfo;
// A per-user, local Mach service. No network socket, global surface IDs or daemon.
const char *mds_service_name(void);
MDSHost *mds_host_create(const char *name);
void mds_host_destroy(MDSHost *host);
uint32_t mds_host_port(MDSHost *host);
// Receive on a dedicated queue. Requests own their surface and reply rights.
MDSRequest *mds_host_receive(MDSHost *host, uint32_t timeout_ms);
uint32_t mds_request_command(const MDSRequest *request);
uint32_t mds_request_width(const MDSRequest *request);
uint32_t mds_request_height(const MDSRequest *request);
uint64_t mds_request_session(const MDSRequest *request);
uint64_t mds_request_sequence(const MDSRequest *request);
pid_t mds_request_pid(const MDSRequest *request);
const char *mds_request_name(const MDSRequest *request);
IOSurfaceRef mds_request_left(const MDSRequest *request) CF_RETURNS_NOT_RETAINED;
IOSurfaceRef mds_request_right(const MDSRequest *request) CF_RETURNS_NOT_RETAINED;
// Always consumes request, even when the client has disconnected. ICC is BEGIN-only.
int mds_request_reply(MDSRequest *request, int status, const MDSInfo *info, CFDataRef icc,
                      const char *message);
MDSClient *mds_client_create(const char *name);
void mds_client_destroy(MDSClient *client);
// One caller at a time. Producer GPU work must finish before MDS_FRAME. Surfaces
// must not be modified until this returns; success means GPU consumption finished.
int mds_client_exchange(MDSClient *client, uint32_t command, uint64_t session, uint64_t sequence,
                        uint32_t width, uint32_t height, const char *label, IOSurfaceRef left,
                        IOSurfaceRef right, uint32_t timeout_ms, MDSInfo *info);
CFDataRef mds_client_copy_icc(MDSClient *client) CF_RETURNS_RETAINED;
const char *mds_client_error(MDSClient *client);
int mds_surface_valid(IOSurfaceRef surface, uint32_t width, uint32_t height);
#ifdef __cplusplus
}
#endif
#endif
