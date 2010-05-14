{ $Header: /MidiComp/MIDICONS.PAS 2     10/06/97 7:33 Davec $ }

{ Written by David Churcher <dchurcher@cix.compulink.co.uk>,
  released to the public domain. }

(**
 * MidiCons.pas v2010-05r1
 **)

(* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1/GPL 3.0/LGPL 3.0
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is MIDI constants.
 *
 * The Initial Developer of the Original Code is
 * David Churcher <dchurcher@cix.compulink.co.uk>.
 * Portions created by the Initial Developer are Copyright (C) 1997
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *   Manuel Kroeber <manuel.kroeber@googlemail.com>
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either the GNU General Public License Version 3 or later (the "GPL"), or
 * the GNU Lesser General Public License Version 3 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the MPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the MPL, the GPL or the LGPL.
 *
 * ***** END LICENSE BLOCK ***** *)
	
{ MIDI Constants }
unit MidiCons;

interface

uses Messages;

const
	MIDI_ALLNOTESOFF = $7B;
	MIDI_NOTEON          = $90;
	MIDI_NOTEOFF         = $80;
	MIDI_KEYAFTERTOUCH   = $a0;
	MIDI_CONTROLCHANGE   = $b0;
	MIDI_PROGRAMCHANGE   = $c0;
	MIDI_CHANAFTERTOUCH  = $d0;
	MIDI_PITCHBEND       = $e0;
	MIDI_SYSTEMMESSAGE   = $f0;
	MIDI_BEGINSYSEX      = $f0;
	MIDI_MTCQUARTERFRAME = $f1;
	MIDI_SONGPOSPTR      = $f2;
	MIDI_SONGSELECT      = $f3;
	MIDI_ENDSYSEX        = $F7;
	MIDI_TIMINGCLOCK     = $F8;
	MIDI_START           = $FA;
	MIDI_CONTINUE        = $FB;
	MIDI_STOP            = $FC;
	MIDI_ACTIVESENSING   = $FE;
	MIDI_SYSTEMRESET     = $FF;

	MIM_OVERFLOW         = WM_USER;	{ Input buffer overflow }
	MOM_PLAYBACK_DONE    = WM_USER+1; { Timed playback complete }

  { device ID for MIDI mapper - copied from MMSystem }
  MIDIMAPPER     = LongWord(-1); // UINT = LongWord as in Windows.pas
  MIDI_MAPPER    = LongWord(-1);

implementation

end.
