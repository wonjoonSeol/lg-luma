//! webOS 6 Home under LG Home's identity. SAM restarts a Home process that never registered with
//! it, and only the program at `/usr/bin/com.webos.app.home` may own the Home bus name that
//! registration needs. `tv/home6.sh` starts Luma with `LUMA_HOME_IDENTITY` set; Luma then mounts
//! its own executable over that path in a private mount namespace and executes it from there, in
//! the same process, so SAM keeps tracking it. Any failure leaves Luma running as before.
use std::{
    ffi::{CString, OsString},
    os::unix::ffi::{OsStrExt, OsStringExt},
    path::Path,
    ptr,
};

pub const HOME_PATH: &str = "/usr/bin/com.webos.app.home";
const MARKER: &str = "LUMA_HOME_IDENTITY";

/// Whether this process runs as LG Home's program, so it may register with SAM.
pub fn adopted() -> bool {
    std::env::current_exe().is_ok_and(|exe| exe == Path::new(HOME_PATH))
}

/// Switches to LG Home's identity when the takeover asks for it. Returns when no switch is
/// needed or it failed; on success the process continues from the top of `main` instead.
pub fn adopt() {
    if std::env::var_os(MARKER).is_none() {
        return;
    }
    // SAFETY: called at the start of `run`, before any other thread exists.
    unsafe { std::env::remove_var(MARKER) };
    if let Err(error) = switch() {
        eprintln!("Luma Home identity: {error}; continuing as Luma");
    }
}

fn switch() -> Result<(), String> {
    let exe = std::env::current_exe().map_err(|e| e.to_string())?;
    let install = exe.parent().ok_or("Luma has no install directory")?;
    let text = |value: &Path| CString::new(value.as_os_str().as_bytes()).map_err(|e| e.to_string());
    let (source, target, root) = (
        text(&exe)?,
        text(Path::new(HOME_PATH))?,
        text(Path::new("/"))?,
    );
    // SAFETY: plain syscalls on valid NUL-terminated paths; only this process's new namespace
    // changes, and making it private first keeps the bind mount out of the system's view.
    unsafe {
        if libc::unshare(libc::CLONE_NEWNS) != 0 {
            return Err(failure("unshare"));
        }
        let private = libc::MS_REC | libc::MS_PRIVATE;
        if libc::mount(
            ptr::null(),
            root.as_ptr(),
            ptr::null(),
            private,
            ptr::null(),
        ) != 0
        {
            return Err(failure("private mounts"));
        }
        if libc::mount(
            source.as_ptr(),
            target.as_ptr(),
            ptr::null(),
            libc::MS_BIND,
            ptr::null(),
        ) != 0
        {
            return Err(failure("bind mount"));
        }
    }
    // From /usr/bin, $ORIGIN no longer finds the bundled libraries or assets.
    let mut libraries = OsString::from(install.join("lib"));
    if let Some(existing) = std::env::var_os("LD_LIBRARY_PATH") {
        libraries.push(":");
        libraries.push(existing);
    }
    // SAFETY: still single-threaded; execv below inherits this environment.
    unsafe { std::env::set_var("LD_LIBRARY_PATH", libraries) };
    let mut args: Vec<OsString> = std::env::args_os().collect();
    if !args.iter().any(|arg| arg == "--assets") {
        args.push("--assets".into());
        args.push(install.join("assets").into_os_string());
    }
    args[0] = HOME_PATH.into();
    let args: Vec<CString> = args
        .into_iter()
        .map(|arg| CString::new(arg.into_vec()).map_err(|e| e.to_string()))
        .collect::<Result<_, _>>()?;
    let mut argv: Vec<*const libc::c_char> = args.iter().map(|arg| arg.as_ptr()).collect();
    argv.push(ptr::null());
    eprintln!("Luma Home identity: running as {HOME_PATH}");
    // SAFETY: argv is NUL-terminated and its strings outlive the call; execv returns only on failure.
    unsafe { libc::execv(target.as_ptr(), argv.as_ptr()) };
    Err(failure("execv"))
}

fn failure(stage: &str) -> String {
    format!("{stage} failed: {}", std::io::Error::last_os_error())
}
