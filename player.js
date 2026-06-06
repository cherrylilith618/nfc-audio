const audio = document.querySelector("#audio");
const player = document.querySelector(".player");
const playButton = document.querySelector("#playButton");
const buttonText = document.querySelector("#buttonText");
const status = document.querySelector("#status");
const duration = player.dataset.duration;

function setPlaying(isPlaying) {
  playButton.dataset.playing = String(isPlaying);
  playButton.setAttribute("aria-label", isPlaying ? "暂停音频" : "播放音频");
  buttonText.textContent = isPlaying ? "暂停" : "播放";
}

playButton.addEventListener("click", async () => {
  if (!audio.paused) {
    audio.pause();
    return;
  }

  try {
    await audio.play();
  } catch {
    status.textContent = "请使用下方播放器开始播放";
  }
});

audio.addEventListener("play", () => {
  setPlaying(true);
  status.textContent = "正在播放";
});

audio.addEventListener("pause", () => {
  setPlaying(false);
  status.textContent = audio.ended ? "播放完毕" : "已暂停";
});

audio.addEventListener("error", () => {
  setPlaying(false);
  status.textContent = "音频加载失败，请检查网络后重试";
});

audio.play().catch(() => {
  status.textContent = `轻触播放按钮开始 · ${duration}`;
});
