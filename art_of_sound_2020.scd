(
s.waitForBoot({
	"Please Wait...".postln;

	~casio = CasioWk7600PatchTable();
	~drum = CasioWk7600Drumkits();
	~counter = 1;
	~delay = 1.3;

    ~win = Window.new;
	~txtview = TextView();
	~win.layout = VLayout(
		[~txtview.string_(~counter.asString), s:3],
		[nil, s:1]
	);
	~txtview.setFont(Font("Arial", 250, true, false, false), 0, 1);
	~win.front;

	MIDIdef.freeAll;
	if (~midi_initialized.isNil) {
		MIDIClient.init;
		MIDIIn.connectAll;
		~midi_initialized = 1;
		~mOut = MIDIOut.newByName("CASIO USB-MIDI", "CASIO USB-MIDI MIDI 1");
		~mOut.latency = 0;
		CmdPeriod.add(
			{
				16.do {
					|i|
					~mOut.allNotesOff(i);
				};
		});
	};

	~notes_occupied = Set[];
	~note_table = ();
	16.do({|midichan| ~note_table[midichan] = 0!128; });
	~extra_notes = []!128;

	fork {
		~channel_info = [
			(\instr: \CLASSICPIANO, \chan: 1, \vel: 120),
			(\instr: \TRUMPET1, \chan: 2, \vel: 125),
			(\instr: \OBOE, \chan: 3, \vel: 120),
			(\instr: \SQUARELEAD1, \chan: 4, \vel: 64),
			(\instr: \PUNGI, \chan: 5, \vel: 64),
		];

		~channel_info.do({
			| instr, idx |
			("set up"+instr[\instr]+"on midi channel"+(instr[\chan])).postln;
			~casio.select(~mOut, instr[\chan], instr[\instr]);
			0.01.wait;
		});
	};

	~task = Task({
		loop {
			~delay.wait;
			~counter = ~counter + 1;
			if (~counter > 4) { ~counter = 1; };
			{
				~txtview.string_(~counter.asString);
				~txtview.setFont(Font("Arial", 250, true, false, false), 0, 1);
			}.defer;
		};
	});
	~task.start;


	~switch_to_one = {
		MIDIdef.freeAll;
		MIDIdef.noteOn(
			\mynoteonhandler, // just a name for this handler
			{
				|val, num, chan, src|
				if (num == 28) {
					~switch_to_two.();
				} {
					~note_table[num] = 1; // update note table and update ~n
					// generate 5 extra notes on different midi channels
					~channel_info.size.do({|idx|
						var offset = 5.rrand(12).neg;
						var newnum = num + offset;
						var pair = [~channel_info[idx][\chan], newnum];
						//pair.debug("on");
						if (~notes_occupied.includesEqual(pair).not) {
							~notes_occupied = ~notes_occupied.add(pair);
							~mOut.noteOn(pair[0], pair[1], val);
							~extra_notes[num] = ~extra_notes[num].add(pair);
							//("switch on"+pair).postln;
						};
					});
				};
			};
		);

		MIDIdef.noteOff(
			\mynoteoffhandler, // just a name for this handler
			{
				|val, num, chan, src|
				~note_table[num] = 0; // update note table and update ~n
				~extra_notes[num].do({
					| pair |
					~mOut.noteOff(pair[0], pair[1]);
					~notes_occupied = ~notes_occupied.remove(pair);
					//("switch off"+pair).postln;
				});
				~extra_notes[num] = [];
			};
		);
		~mOut.latency = 0;

		~delay = 1.53;
	};

	~switch_to_two = {
		MIDIdef.freeAll;
		MIDIdef.noteOn(
			\mynoteonhandler, // just a name for this handler
			{
				|val, num, chan, src|
				var tkey = ("t_"++num).asSymbol;
				if (num == 28) {
					~switch_to_one.();
				} {
					~note_table[num.debug] = 1; // update note table and update ~n
					Tdef.defaultQuant = 0;
					Tdef(tkey, {
						loop {
							var oct = 0;
							var length = 0.1.rrand(0.3);
							var note;
							var octaviatednote;
							var pitchclassoffset = [-1,0,0,0,1].choose;
							var velfactor = 1.0;
							var chaninfo = ~channel_info.choose;
							while ({oct == 0}, { oct = (1.neg).rrand(1); });
							octaviatednote = num + (12*oct) + pitchclassoffset;
							if (pitchclassoffset != 0) { velfactor = 0.6; };
							note = [octaviatednote.debug("normal"), (76 + (76 - octaviatednote)).debug("mirror")].choose;
							~mOut.noteOn(chaninfo[\chan], note, (val*velfactor).asInteger);
							SystemClock.sched(length, { ~mOut.noteOff(chaninfo[\chan], note); });
							0.05.wait;
						};
					});
					Tdef(tkey).play;
				};
			};
		);

		MIDIdef.noteOff(
			\mynoteoffhandler, // just a name for this handler
			{
				|val, num, chan, src|
				var tkey = ("t_"++num).asSymbol;
				~note_table[num] = 0; // update note table and update ~n
				Tdef(tkey).stop;
			};
		);
		~mOut.latency = 0;
		~delay = 1.3;
	};




	~switch_to_one.();

	"And GO!!!".postln;
});
)