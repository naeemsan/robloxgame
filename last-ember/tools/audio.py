"""Generate original nonverbal horror audio. No sampled recordings or external assets."""
from pathlib import Path
import math
import wave
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
RATE=44100
rng=np.random.default_rng(713)
def timeline(seconds):return np.arange(round(seconds*RATE))/RATE
def smooth_noise(n,window):
    raw=rng.normal(size=n)
    # Low-pass the noise in frequency space to avoid expensive long convolutions.
    fft=np.fft.rfft(raw)
    frequencies=np.fft.rfftfreq(n,1/RATE)
    fft*=np.exp(-(frequencies/window)**2)
    data=np.fft.irfft(fft,n)
    return data/(np.max(np.abs(data))+1e-9)
def export(name,data,loop=False):
    data=np.tanh(data*1.2)
    if loop:
        # Periodic amplitude at the boundary; short fade guarantees click-free looping.
        pass
    fade=min(int(RATE*.04),len(data)//10)
    data[:fade]*=np.linspace(0,1,fade);data[-fade:]*=np.linspace(1,0,fade)
    peak=np.max(np.abs(data))
    if peak>0:data=data/peak*.72
    output=ROOT/'assets'/'audio'/f'{name}.wav';output.parent.mkdir(parents=True,exist_ok=True)
    with wave.open(str(output),'wb') as f:
        f.setnchannels(1);f.setsampwidth(2);f.setframerate(RATE)
        f.writeframes((data*32767).astype('<i2').tobytes())
    return output
def generate():
    global rng
    rng=np.random.default_rng(713)
    t=timeline(24)
    drone=.2*np.sin(2*np.pi*48*t)+.13*np.sin(2*np.pi*49.5*t)+.1*np.sin(2*np.pi*73*t)
    drone+=.12*smooth_noise(len(t),500)*(1+.4*np.sin(2*np.pi*.17*t))
    export('Drone',drone,True)
    t=timeline(8)
    whisper=smooth_noise(len(t),2600)*(.2+.8*np.sin(np.pi*t/8)**2)
    whisper*=.5+.5*np.sin(2*np.pi*3.7*t+.9*np.sin(t))
    export('Whisper',whisper)
    t=timeline(2.5)
    impact=(np.sin(2*np.pi*(95*t-14*t*t))+.4*rng.normal(size=len(t)))*np.exp(-3.2*t)
    export('Impact',impact)
    t=timeline(2)
    phase=2*np.pi*(175*t+90*t*t+5*np.sin(2*np.pi*6*t))
    scream=(.4*np.sin(phase)+.3*np.sin(phase*1.41)+.3*smooth_noise(len(t),3500))
    scream*=np.minimum(t/.08,1)*np.maximum(0,1-t/2)**.6
    export('Scream',scream)
    t=timeline(4)
    bell=sum(np.sin(2*np.pi*f*t)*a*np.exp(-t*d) for f,a,d in [(277,.5,1.1),(398,.25,1.4),(761,.16,2),(1123,.08,3)])
    export('Bell',bell)
    t=timeline(1.1)
    heart=np.zeros(len(t))
    for start,amplitude in [(0,.8),(.24,.55)]:
        local=t-start;positive=local>=0
        heart+=positive*amplitude*np.sin(2*np.pi*63*np.maximum(local,0))*np.exp(-22*np.maximum(local,0))
    export('Heartbeat',heart)
    t=timeline(4)
    fire=smooth_noise(len(t),1500)*.3
    for _ in range(28):
        center=rng.integers(0,len(t)-600);fire[center:center+600]+=rng.normal(size=600)*np.exp(-np.arange(600)/100)*.25
    fire*=np.minimum(t/.2,1)*np.minimum((4-t)/.7,1)
    export('Burn',fire)
    print('Generated 7 original PCM WAV files, normalized below full scale.')
if __name__=='__main__':generate()
