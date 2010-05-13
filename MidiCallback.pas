{ $Header: /MidiComp/DELPHMCB.PAS 2     10/06/97 7:33 Davec $ }

(**
 * VALID FOR ALL MODIFICATIONS TO ORIGINAL SOURCE
 * DelphiMidiCallback.pas v2010-05r1
 *
 *    Author: Manuel Kr�ber
 *      Mail: manuel.kroeber@googlemail.com
 *       Web: http://saso-labs.com/
 * Copyright: (c)2009-2010 by Manuel Kr�ber
 *
 * This source is licensed under the Mozilla Public License 1.1 (MPL 1.1).
 * See LICENSE file or http://www.opensource.org/licenses/mozilla1.1.php for
 * a reference.
 **)
 

{MIDI callback for Delphi, was DLL for Delphi 1}

unit MidiCallback;

{ These segment options required for the MIDI callback functions }
{$C PRELOAD FIXED PERMANENT}

interface

uses WinProcs, WinTypes, MMsystem, Circbuf, MidiDefs, MidiCons;

{$IFDEF WIN32}
procedure midiHandler(
  hMidiIn: HMidiIn;
  wMsg: UINT;
  dwInstance: DWORD;
  dwParam1: DWORD;
  dwParam2: DWORD); stdcall export;
function CircbufPutEvent(PBuffer: PCircularBuffer; PTheEvent: PMidiBufferItem): Boolean; stdcall; export;
{$ELSE}
procedure midiHandler(
  hMidiIn: HMidiIn;
  wMsg: Word;
  dwInstance: DWORD;
  dwParam1: DWORD;
  dwParam2: DWORD); export;
function CircbufPutEvent(PBuffer: PCircularBuffer; PTheEvent: PMidiBufferItem): Boolean; export;
{$ENDIF}

implementation

{ Add an event to the circular input buffer. }

function CircbufPutEvent(PBuffer: PCircularBuffer; PTheEvent: PMidiBufferItem): Boolean;
begin
  if (PBuffer^.EventCount < PBuffer^.Capacity) then
  begin
    Inc(Pbuffer^.EventCount);

  { Todo: better way of copying this record }
    with PBuffer^.PNextput^ do
    begin
      Timestamp := PTheEvent^.Timestamp;
      Data := PTheEvent^.Data;
      Sysex := PTheEvent^.Sysex;
    end;

  { Move to next put location, with wrap }
    Inc(Pbuffer^.PNextPut);
    if (PBuffer^.PNextPut = PBuffer^.PEnd) then
      PBuffer^.PNextPut := PBuffer^.PStart;

    CircbufPutEvent := True;
  end
  else
    CircbufPutEvent := False;
end;

{ This is the callback function specified when the MIDI device was opened
  by midiInOpen. It's called at interrupt time when MIDI input is seen
  by the MIDI device driver(s). See the docs for midiInOpen for restrictions
  on the Windows functions that can be called in this interrupt. }

procedure midiHandler(
  hMidiIn: HMidiIn;
  wMsg: UINT;
  dwInstance: DWORD;
  dwParam1: DWORD;
  dwParam2: DWORD);

var
  thisEvent: TMidiBufferItem;
  thisCtlInfo: PMidiCtlInfo;
  thisBuffer: PCircularBuffer;

begin
  case wMsg of

    mim_Open: {nothing};

    mim_Error: {TODO: handle (message to trigger exception?) };

    mim_Data, mim_Longdata, mim_Longerror:
   { Note: mim_Longerror included because there's a bug in the Maui
   input driver that sends MIM_LONGERROR for subsequent buffers when
   the input buffer is smaller than the sysex block being received }

      begin
   { TODO: Make filtered messages customisable, I'm sure someone wants to
   do something with MTC! }
        if (dwParam1 <> MIDI_ACTIVESENSING) and
          (dwParam1 <> MIDI_TIMINGCLOCK) then
        begin

    { The device driver passes us the instance data pointer we
    specified for midiInOpen. Use this to get the buffer address
    and window handle for the MIDI control }
          thisCtlInfo := PMidiCtlInfo(dwInstance);
          thisBuffer := thisCtlInfo^.PBuffer;

    { Screen out short messages if we've been asked to }
          if ((wMsg <> mim_Data) or (thisCtlInfo^.SysexOnly = False))
            and (thisCtlInfo <> nil) and (thisBuffer <> nil) then
          begin
            with thisEvent do
            begin
              timestamp := dwParam2;
              if (wMsg = mim_Longdata) or
                (wMsg = mim_Longerror) then
              begin
                data := 0;
                sysex := PMidiHdr(dwParam1);
              end
              else
              begin
                data := dwParam1;
                sysex := nil;
              end;
            end;
            if CircbufPutEvent(thisBuffer, @thisEvent) then
      { Send a message to the control to say input's arrived }
              PostMessage(thisCtlInfo^.hWindow, mim_Data, 0, 0)
            else
      { Buffer overflow }
              PostMessage(thisCtlInfo^.hWindow, mim_Overflow, 0, 0);
          end;
        end;
      end;

    mom_Done: { Sysex output complete, dwParam1 is pointer to MIDIHDR }
      begin
   { Notify the control that its sysex output is finished.
     The control should call midiOutUnprepareHeader before freeing the buffer }
        PostMessage(PMidiCtlInfo(dwInstance)^.hWindow, mom_Done, 0, dwParam1);
      end;

  end; { Case }
end;

end.

