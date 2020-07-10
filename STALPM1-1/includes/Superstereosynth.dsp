declare name "Superstereo Synth";
declare description "Subtractive Phaser Modulated Synth";
declare author "Davide Croci";
declare author "Giuseppe Messineo";
declare author "Gianmarco Romiti";

import("stdfaust.lib");

// GUI
main(x) = hgroup("[01] Superstereo Synth",x);
s_g(x) = main(vgroup("[01] SUBTRACTIVE",x));
m_g(x) = main(vgroup("[03] MASTER",x));
p_g(x) = main(vgroup("[05] PHASER",x));
lmeter(x) = main(attach(x,an.amp_follower(0.150,x):ba.linear2db:vbargraph("[02] L [unit:dB]", -70,0)));
rmeter(x) = main(attach(x,an.amp_follower(0.150,x):ba.linear2db:vbargraph("[04] R [unit:dB]", -70,0)));
meters = lmeter, rmeter;

// SUBTRACTIVE
// Sawfreq Custom
sawfreq = 123;
generator = (no.noise *switch),(os.sawtooth(sawfreq)*(1-switch)) :> _;
switch = s_g(checkbox("[01] Saw/Noise")) : si.smoo;
gain = s_g(vslider("[04] Gain [style:knob]",-12,-96,+12,0.01)) : ba.db2linear : si.smoo;
Q = s_g(vslider("[03] Q [style:knob]",5,0.7072,25,0.01));
fcut = s_g( vslider("[02] Cut [style:knob]",0.65,0,1,0.001)) : si.smoo;
subtractive = generator : ve.moogLadder(fcut,Q) : *(gain);

// PHASER
lff = p_g(vslider("[02] Lfo [style:knob]", 0.358, 0, 16, 0.001)) : si.smoo;
fbk = p_g(vslider("[03] Feedback [style:knob]", -0.689, -0.999, 0.999, 0.001) : si.smoo);
del = p_g(nentry("[04] Delay [style:knob]", 1, 1, 100, 1));

lfo = os.osc(lff);

phaserLR(N,x,d,g,fb) = x <: l,r
with{
  allpassL(d,g) = (+ <: de.fdelay((ma.SR/2),d),*(-g)) ~ *(g) : mem,_ : +;
  allpassR(d,g) = (+ <: de.fdelay((ma.SR/2),d),*(g)) ~ *(-g) : mem,_ : +;
  apseqL(N,d,g) = seq(i,N,allpassL(d,g));
  apseqR(N,d,g) = seq(i,N,allpassR(d,g));

  l= _, (+:apseqL(N,d,g))~*(fb):> _;
  r=  _, (+:apseqR(N,d,g))~*(-fb):> _;
};

// STEREO SHUFFLER
pot = m_g(vslider("[02] WIDE [style:knob]",100,0,200,0.1)) : /(100) : si.smoo;
somma = + : /(2);
diff = - : /(2);
sdm = somma,diff;
wide = _, * (sqrt(pot));
stereoshuffle= _,_ <: sdm : wide <: sdm;

// N all-pass custom (min = sharp | max = smooth)
superstereophaser = phaserLR(4,_,del,lfo,fbk) : stereoshuffle;

// HARD LIMITER
chopper(a) = min(a) : max(-a);

// Chopper amp custom | Filter order custom | Filter freq custom
hardlimiter = chopper(0.7) : fi.lowpass(12,15000): chopper(0.9) : fi.lowpass6e(20000);
phchop = superstereophaser : hardlimiter, hardlimiter;

// MASTER CONTROLS
mute=m_g(*(1-(checkbox("[04] Mute")))) : si.smoo;
volume = m_g(vslider("[02] VOLUME ",-6,-70,12,0.1)) : ba.db2linear : si.smoo;
bpc = p_g(checkbox("[01] Bypass"));
phaser = ba.bypass1to2(bpc,phchop);
mutes = mute,mute;
master = (*(volume), *(volume));

process= subtractive : phaser : master : mutes : meters;
