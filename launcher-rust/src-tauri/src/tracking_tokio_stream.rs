use std::{
    pin::Pin,
    task::{Context, Poll},
};

use futures_core::Stream;
use tokio_util::bytes::Bytes;

pub struct TrackingTokioStream<R, F> {
    inner: R,
    sent: u64,
    on_progress: F,
}

impl<R, F> TrackingTokioStream<R, F>
where
    R: tokio::io::AsyncRead + Unpin,
    F: FnMut(u64) + Unpin,
{
    pub fn new(source: R, callback: F) -> Self {
        Self {
            inner: source,
            sent: 0,
            on_progress: callback,
        }
    }
}

impl<R, F> Stream for TrackingTokioStream<R, F>
where
    R: tokio::io::AsyncRead + Unpin,
    F: FnMut(u64) + Unpin,
{
    type Item = std::io::Result<Bytes>;

    fn poll_next(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Option<Self::Item>> {
        let mut tmp = [0u8; 8192];
        let mut rb = tokio::io::ReadBuf::new(&mut tmp);

        match Pin::new(&mut self.inner).poll_read(cx, &mut rb) {
            Poll::Ready(Ok(())) => {
                let filled = rb.filled();

                if filled.is_empty() {
                    return Poll::Ready(None);
                }

                let sent = filled.len() as u64;
                self.sent = sent;
                (self.on_progress)(sent);

                Poll::Ready(Some(Ok(Bytes::copy_from_slice(filled))))
            }
            Poll::Ready(Err(e)) => Poll::Ready(Some(Err(e))),
            Poll::Pending => Poll::Pending,
        }
    }
}
