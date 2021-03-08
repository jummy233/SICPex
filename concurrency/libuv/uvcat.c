// asynchronous cat.

#include <assert.h>
#include <stdio.h>
#include <uv.h>

void on_read(uv_fs_t *req);

// define three handlers.
uv_fs_t open_req;
uv_fs_t read_req;
uv_fs_t write_req;

static char buffer[1024];

// uv_buf_t can be cast to iovec.
static uv_buf_t iov;

void on_write(uv_fs_t *req) {
  if (req->result < 0) {
    // if an error occur, the result will be the error code.
    fprintf(stderr, "Write error: %s\n", uv_strerror((int)req->result));

  } else {
    // write to the opened file, which is open_req.result.
    uv_fs_read(uv_default_loop(), &read_req, open_req.result, &iov, 1, -1,
               on_read);

  }
}

void on_read(uv_fs_t *req) {
  if (req->result < 0) {
    fprintf(stderr, "Read error: %s\n", uv_strerror((int)req->result));

  } else if (req->result == 0) { // nothing to read
    // synchronous. because close is small task
    uv_fs_t close_req;

    // close the opened file, which is open_req.result.
    uv_fs_close(uv_default_loop(), &close_req, open_req.result, NULL);

  } else if (req->result > 0) {
    iov.len = req->result;
    uv_fs_write(uv_default_loop(), &write_req, 1, &iov, 1, -1, on_write);
  }
}

// open handler
void on_open(uv_fs_t *req) {
  assert(req == &open_req);   // this is the same req we passed to uv_fs_open.

  if (req->result >= 0) {
    iov = uv_buf_init(buffer, sizeof(buffer));
    uv_fs_read(uv_default_loop(), &read_req, req->result, &iov, 1, -1, on_read);
  } else {
    fprintf(stderr, "Error opening file %s\n", uv_strerror((int)req->result));
  }
}

int main(int argc, char *argv[]) {
  uv_fs_open(uv_default_loop(), &open_req, argv[1], O_RDONLY, 0, on_open);

  uv_run(uv_default_loop(), UV_RUN_DEFAULT);

  uv_fs_req_cleanup(&open_req);
  uv_fs_req_cleanup(&read_req);
  uv_fs_req_cleanup(&write_req);

  return 0;
}
