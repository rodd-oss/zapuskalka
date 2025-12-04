use std::io::Write;

pub struct TrackingWriter<T: Write, F: FnMut(&[u8])> {
    pub target: T,
    pub callback: F,
}

impl<T: Write, F: FnMut(&[u8])> TrackingWriter<T, F> {
    pub fn new(target: T, callback: F) -> Self {
        Self { target, callback }
    }

    pub fn into_inner(self) -> T {
        self.target
    }
}

impl<T: Write, F: FnMut(&[u8])> Write for TrackingWriter<T, F> {
    fn write(&mut self, buf: &[u8]) -> std::io::Result<usize> {
        (self.callback)(buf);
        self.target.write(buf)
    }

    fn flush(&mut self) -> std::io::Result<()> {
        self.target.flush()
    }
}
