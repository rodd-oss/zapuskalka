use std::io::Read;

pub struct TrackingReader<T: Read, F: FnMut(&mut [u8])> {
    pub source: T,
    pub callback: F,
}

impl<T: Read, F: FnMut(&mut [u8])> TrackingReader<T, F> {
    pub fn new(source: T, callback: F) -> Self {
        Self { source, callback }
    }
}

impl<T: Read, F: FnMut(&mut [u8])> Read for TrackingReader<T, F> {
    fn read(&mut self, buf: &mut [u8]) -> std::io::Result<usize> {
        let res = self.source.read(buf);
        if res.is_err() {
            return res;
        }

        (self.callback)(buf);
        res
    }
}
