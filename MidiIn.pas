{ $Header: /MidiComp/Midiin.pas 4     28/02/01 11:35 Davec $ }

{ Written by David Churcher <dchurcher@cix.compulink.co.uk>,
  released to the public domain. }

(**
 * MidiIn.pas v2010-05r1
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
 *   turboPASCAL < http://www.delphipraxis.net/user13047.html >
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

unit MidiIn;

{
  Properties:
	DeviceID: 	Windows numeric device ID for the MIDI input device.
	Between 0 and NumDevs-1.
	Read-only while device is open, exception when changed while open

	MIDIHandle:	The input handle to the MIDI device.
	0 when device is not open
	Read-only, runtime-only

	MessageCount:	Number of input messages waiting in input buffer

	Capacity:	Number of messages input buffer can hold
	Defaults to 1024
	Limited to (64K/event size)
	Read-only when device is open (exception when changed while open)

	SysexBufferSize:	Size in bytes of each sysex buffer
	Defaults to 10K
	Minimum 0K (no buffers), Maximum 64K-1

	SysexBufferCount:	Number of sysex buffers
	Defaults to 16
	Minimum 0 (no buffers), Maximum (avail mem/SysexBufferSize)
	Check where these buffers are allocated?

	SysexOnly: True to ignore all non-sysex input events. May be changed while
	device is open. Handy for patch editors where you have lots of short MIDI
	events on the wire which you are always going to ignore anyway.

	DriverVersion: Version number of MIDI device driver. High-order byte is
	major version, low-order byte is minor version.

	ProductName: Name of product (e.g. 'MPU 401 In')

	MID and PID: Manufacturer ID and Product ID, see
	"Manufacturer and Product IDs" in MMSYSTEM.HLP for list of possible values.

  Methods:
	GetMidiEvent: Read Midi event at the head of the FIFO input buffer.
	Returns a TMyMidiEvent object containing MIDI message data, timestamp,
	and sysex data if applicable.
	This method automatically removes the event from the input buffer.
	It makes a copy of the received sysex buffer and puts the buffer back
	on the input device.
	The TMyMidiEvent object must be freed by calling MyMidiEvent.Free.

	Open: Opens device. Note no input will appear until you call the Start
	method.

	Close: Closes device. Any pending system exclusive output will be cancelled.

	Start: Starts receiving MIDI input.

	Stop: Stops receiving MIDI input.

  Events:
	OnMidiInput: Called when MIDI input data arrives. Use the GetMidiEvent to
	get the MIDI input data.

	OnOverflow: Called if the MIDI input buffer overflows. The caller must
	clear the buffer before any more MIDI input can be received.

 Notes:
	Buffering: Uses a circular buffer, separate pointers for next location
	to fill and next location to empty because a MIDI input interrupt may
	be adding data to the buffer while the buffer is being read. Buffer
	pointers wrap around from end to start of buffer automatically. If
	buffer overflows then the OnBufferOverflow event is triggered and no
	further input will be received until the buffer is emptied by calls
	to GetMidiEvent.

	Sysex buffers: There are (SysexBufferCount) buffers on the input device.
	When sysex events arrive these buffers are removed from the input device and
	added to the circular buffer by the interrupt handler in the DLL.  When the sysex events
	are removed from the circular buffer by the GetMidiEvent method the buffers are
	put back on the input. If all the buffers are used up there will be no
	more sysex input until at least one sysex event is removed from the input buffer.
	In other	words if you're expecting lots of sysex input you need to set the
	SysexBufferCount property high enough so that you won't run out of
	input buffers before you get a chance to read them with GetMidiEvent.

	If the synth sends a block of sysex that's longer than SysexBufferSize it
	will be received as separate events.
	TODO: Component derived from this one that handles >64K sysex blocks cleanly
	and can stream them to disk.

	Midi Time Code (MTC) and Active Sensing: The DLL is currently hardcoded
	to filter these short events out, so that we don't spend all our time
	processing them.
	TODO: implement a filter property to select the events that will be filtered
	out.
}

interface

uses
  Classes, SysUtils, Messages, Windows,

  MMSystem,
  MidiDefs, MidiType, MidiCons, CircBuf, MidiCallback;

type
	MidiInputState = (misOpen, misClosed, misCreating, misDestroying);
	EMidiInputError = class(Exception);

	{-------------------------------------------------------------------}
  TMidiInput = class(TMidiIO)
  private
    Handle: THandle; { Window handle used for callback notification }
    FDeviceID: Cardinal; { MIDI device ID }
    FMIDIHandle: HMIDIIn; { Handle to input device }
    FState: MidiInputState; { Current device state }

    FError: Word;
    FSysexOnly: Boolean;
    FMsgFilter: TMidiMsgFilter;

    { Stuff from MIDIINCAPS }
    FDriverVersion: Version;
    FProductName: string;
    FMID: Word; { Manufacturer ID }
    FPID: Word; { Product ID }

    { Queue }
    FCapacity: Word; { Buffer capacity }
    PBuffer: PCircularBuffer; { Low-level MIDI input buffer created by Open method }
    FNumDevs: Cardinal; { Number of input devices on system }

    { Events }
    FOnMIDIInput: TNotifyEvent; { MIDI Input arrived }
    FOnOverflow: TNotifyEvent; { Input buffer overflow }
    FOnDeviceChanged: TNotifyEvent; // after successfully changing the DeviceID
    { TODO: Some sort of error handling event for MIM_ERROR }

    { Sysex }
    FSysexBufferSize: Word;
    FSysexBufferCount: Word;
    MidiHdrs: Tlist;

    PCtlInfo: PMidiCtlInfo; { Pointer to control info for DLL }

  protected
    procedure Prepareheaders;
    procedure UnprepareHeaders;
    procedure AddBuffers;
    procedure SetDeviceID(DeviceID: Cardinal);
    procedure SetProductName(NewProductName: String);
    function GetEventCount: Word;
    procedure SetSysexBufferSize(const BufferSize: Word);
    procedure SetSysexBufferCount(const BufferCount: Word);
    procedure SetSysexOnly(const bSysexOnly: Boolean);
    procedure SetMsgFilter(const Value: TMidiMsgFilter);
    function MidiInErrorString(WError: Word): String;

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    property MIDIHandle: HMIDIIn read FMIDIHandle;

    property DriverVersion: Version read FDriverVersion;
    property MID: Word read FMID; { Manufacturer ID }
    property PID: Word read FPID; { Product ID }

    property NumDevs: Cardinal read FNumDevs; // Buffered output

    property MessageCount: Word read GetEventCount;
    property State: MidiInputState read FState;

    procedure Open;
    procedure Close;
    procedure Start;
    procedure Stop;

    function DeviceCount: Cardinal; override;

    procedure OpenAndStart;
    procedure StopAndClose;

    procedure ChangeDevice(const NewDeviceID: Cardinal;
      const OpenAndStartAfterChange: Boolean = True);

    { Get first message in input queue }
    function GetMidiEvent: TMyMidiEvent;
    procedure MidiInput(var AMessage: TMessage);
    procedure FlushQueue; // discard all queued events

    { Some functions to decode and classify incoming messages would be good }

  published
    { TODO: Property editor with dropdown list of product names }
    property ProductName: String read FProductName write SetProductName;

    property DeviceID: Cardinal read FDeviceID write SetDeviceID default 0;
    property Capacity: Word read FCapacity write FCapacity default 1024;
    property Error: Word read FError;
    property SysexBufferSize
      : Word read FSysexBufferSize write SetSysexBufferSize default 10000;
    property SysexBufferCount
      : Word read FSysexBufferCount write SetSysexBufferCount default 16;
    property SysexOnly
      : Boolean read FSysexOnly write SetSysexOnly default False;
    property FilteredMessages
      : TMidiMsgFilter read FMsgFilter write SetMsgFilter;


    { Events }
    property OnMidiInput: TNotifyEvent read FOnMIDIInput write FOnMIDIInput;
    property OnOverflow: TNotifyEvent read FOnOverflow write FOnOverflow;
    property OnDeviceChanged: TNotifyEvent
      read FOnDeviceChanged write FOnDeviceChanged;
  end;

procedure Register;

{====================================================================}
implementation

{-------------------------------------------------------------------}
constructor TMidiInput.Create(AOwner:TComponent);
begin
	inherited Create(AOwner);
	FState := misCreating;

	FSysexOnly := False;
	FNumDevs := midiInGetNumDevs;
  MidiHdrs := Nil;
  FMidiHandle := 0;

	{ Set defaults }
  if FNumDevs > 0 then
  	SetDeviceID(0);
	FCapacity := 1024;
	FSysexBufferSize := 4096;
	FSysexBufferCount := 16;

	{ Create the window for callback notification }
	if not (csDesigning in ComponentState) then
  begin
		Handle := Classes.AllocateHWnd(MidiInput);
	end;

  PCtlInfo := nil;
  FMsgFilter := [msgActiveSensing, msgMidiTimeCode];

	FState := misClosed;
end;

{-------------------------------------------------------------------}
{ Close the device if it's open }
destructor TMidiInput.Destroy;
begin
	if (FMidiHandle <> 0) then
  begin
		Close;
		FMidiHandle := 0;
	end;

	if (PCtlInfo <> nil) then
		GlobalSharedLockedFree( PCtlinfo^.hMem, PCtlInfo );

	Classes.DeallocateHWnd(Handle);

	inherited Destroy;
end;

function TMidiInput.DeviceCount: Cardinal;
begin
  FNumDevs := midiInGetNumDevs;
  Result := FNumDevs;
end;

procedure TMidiInput.FlushQueue;
begin
  while (MessageCount > 0) do
  begin
    // get event and free it immediatly
    GetMidiEvent.Free;
  end;
end;

{-------------------------------------------------------------------}
{ Convert the numeric return code from an MMSYSTEM function to a string
  using midiInGetErrorText. TODO: These errors aren't very helpful
  (e.g. "an invalid parameter was passed to a system function") so
  sort out some proper error strings. }
function TMidiInput.MidiInErrorString( WError: Word ): String;
var
	errorDesc: PChar;
begin
     errorDesc := Nil;
	try
		errorDesc := StrAlloc(MAXERRORLENGTH);
		if midiInGetErrorText(WError, errorDesc, MAXERRORLENGTH) = 0 then
			result := StrPas(errorDesc)
		else
			result := 'Specified error number is out of range';
	finally
               if errorDesc <> Nil then StrDispose(errorDesc);
	end;
end;

{-------------------------------------------------------------------}
{ Set the sysex buffer size, fail if device is already open }
procedure TMidiInput.SetSysexBufferSize(const BufferSize: Word);
begin
	if FState = misOpen then
		raise EMidiInputError.Create('Change to SysexBufferSize while device was open')
	else
		{ TODO: Validate the sysex buffer size. Is this necessary for WIN32? }
		FSysexBufferSize := BufferSize;
end;

{-------------------------------------------------------------------}
{ Set the sysex buffer count, fail if device is already open }
procedure TMidiInput.SetSysexBufferCount(const BufferCount: Word);
begin
	if FState = misOpen then
		raise EMidiInputError.Create('Change to SysexBufferCount while device was open')
	else
		{ TODO: Validate the sysex buffer count }
		FSysexBufferCount := BufferCount;
end;

{-------------------------------------------------------------------}
{ Set the Sysex Only flag to eliminate unwanted short MIDI input messages }
procedure TMidiInput.SetSysexOnly(const bSysexOnly: Boolean);
begin
	FSysexOnly := bSysexOnly;
	{ Update the interrupt handler's copy of this property }
	if PCtlInfo <> Nil then
		PCtlInfo^.SysexOnly := bSysexOnly;
end;

{-------------------------------------------------------------------}
{ Set the Device ID to select a new MIDI input device
  Note: If no MIDI devices are installed, throws an 'Invalid Device ID' exception }
procedure TMidiInput.SetDeviceID(DeviceID: Cardinal);
var
	MidiInCaps: TMidiInCaps;
begin
	if FState = misOpen then
		raise EMidiInputError.Create('Change to DeviceID while device was open')
	else
  begin
		if (DeviceID >= midiInGetNumDevs) and (DeviceID <> MIDI_MAPPER) then
			raise EMidiInputError.Create('Invalid device ID')
		else
    begin
			FDeviceID := DeviceID;

			{ Set the name and other MIDIINCAPS properties to match the ID }
			FError :=
				midiInGetDevCaps(DeviceID, @MidiInCaps, sizeof(TMidiInCaps));

			if Ferror <> MMSYSERR_NOERROR then
				raise EMidiInputError.Create(MidiInErrorString(FError));

			FProductName := StrPas(MidiInCaps.szPname);
			FDriverVersion := MidiInCaps.vDriverVersion;
			FMID := MidiInCaps.wMID;
			FPID := MidiInCaps.wPID;

      if Assigned(FOnDeviceChanged) then
        FOnDeviceChanged(Self);
    end;
  end;
end;

procedure TMidiInput.SetMsgFilter(const Value: TMidiMsgFilter);
begin
  FMsgFilter := Value;

  if (PCtlInfo <> nil) then
  begin
		PCtlInfo^.FilterMTC := (msgMidiTimeCode in FMsgFilter);
    PCtlInfo^.FilterAS := (msgActiveSensing in FMsgFilter);
  end;
end;

{-------------------------------------------------------------------}
{ Set the product name and put the matching input device number in FDeviceID.
  This is handy if you want to save a configured input/output device
  by device name instead of device number, because device numbers may
  change if users add or remove MIDI devices.
  Exception if input device with matching name not found,
  or if input device is open }
procedure TMidiInput.SetProductName( NewProductName: String );
var
	MidiInCaps: TMidiInCaps;
	testDeviceID: Cardinal;
	testProductName: String;
begin
	if FState = misOpen then
		raise EMidiInputError.Create('Change to ProductName while device was open')
	else
  { Don't set the name if the component is reading properties because
	the saved Productname will be from the machine the application was compiled
	on, which may not be the same for the corresponding DeviceID on the user's
	machine. The FProductname property will still be set by SetDeviceID }
	if not (csLoading in ComponentState) then
	begin
		begin
		for testDeviceID := 0 To (midiInGetNumDevs-1) do
			begin
			FError :=
				midiInGetDevCaps(testDeviceID, @MidiInCaps, sizeof(TMidiInCaps));
			if Ferror <> MMSYSERR_NOERROR then
				raise EMidiInputError.Create(MidiInErrorString(FError));
			testProductName := StrPas(MidiInCaps.szPname);
			if testProductName = NewProductName then
				begin
				FProductName := NewProductName;
				Break;
				end;
			end;
		if FProductName <> NewProductName then
			raise EMidiInputError.Create('MIDI Input Device ' +
				NewProductName + ' not installed ')
		else
			SetDeviceID(testDeviceID);
		end;
	end;
end;


{-------------------------------------------------------------------}
{ Get the sysex buffers ready }
procedure TMidiInput.PrepareHeaders;
var
	ctr: Word;
	MyMidiHdr: TMyMidiHdr;
begin
	if (FSysexBufferCount > 0) And (FSysexBufferSize > 0)
		And (FMidiHandle <> 0) then
		begin
		Midihdrs := TList.Create;
		for ctr := 1 to FSysexBufferCount do
			begin
			{ Initialize the header and allocate buffer memory }
			MyMidiHdr := TMyMidiHdr.Create(FSysexBufferSize);

			{ Store the address of the MyMidiHdr object in the contained MIDIHDR
              structure so we can get back to the object when a pointer to the
              MIDIHDR is received.
              E.g. see TMidiOutput.Output method }
			MyMidiHdr.hdrPointer^.dwUser := DWORD(MyMidiHdr);

			{ Get MMSYSTEM's blessing for this header }
			FError := midiInPrepareHeader(FMidiHandle,MyMidiHdr.hdrPointer,
				sizeof(TMIDIHDR));
			if Ferror <> MMSYSERR_NOERROR then
				raise EMidiInputError.Create(MidiInErrorString(FError));

			{ Save it in our list }
			MidiHdrs.Add(MyMidiHdr);
			end;
		end;

end;

{-------------------------------------------------------------------}
{ Clean up from PrepareHeaders }
procedure TMidiInput.UnprepareHeaders;
var
	ctr: Word;
begin
    if (MidiHdrs<> Nil) then	{ will be Nil if 0 sysex buffers }
 	   begin
       for ctr := 0 To MidiHdrs.Count-1 do
       		begin
            FError := midiInUnprepareHeader( FMidiHandle,
            	TMyMidiHdr(MidiHdrs.Items[ctr]).hdrPointer,
                sizeof(TMIDIHDR));
            if Ferror <> MMSYSERR_NOERROR then
            	raise EMidiInputError.Create(MidiInErrorString(FError));
            TMyMidiHdr(MidiHdrs.Items[ctr]).Free;
       		end;
       MidiHdrs.Free;
       MidiHdrs := Nil;
       end;
end;

{-------------------------------------------------------------------}
{ Add sysex buffers, if required, to input device }
procedure TMidiInput.AddBuffers;
var
	ctr: Word;
begin
	if MidiHdrs <> Nil then		{ will be Nil if 0 sysex buffers }
    	begin
        if MidiHdrs.Count > 0 Then
            begin
            for ctr := 0 To MidiHdrs.Count-1 do
                begin
                FError := midiInAddBuffer(FMidiHandle,
                    TMyMidiHdr(MidiHdrs.Items[ctr]).hdrPointer,
                    sizeof(TMIDIHDR));
                If FError <> MMSYSERR_NOERROR then
                    raise EMidiInputError.Create(MidiInErrorString(FError));
                end;
            end;
        end;
end;

{-------------------------------------------------------------------}
procedure TMidiInput.Open;
var
	hMem: THandle;
begin
	try
		{ Create the buffer for the MIDI input messages }
		if (PBuffer = Nil) then
			PBuffer := CircBufAlloc( FCapacity );

		{ Create the control info for the DLL }
		if (PCtlInfo = Nil) then
		begin
			PCtlInfo := GlobalSharedLockedAlloc( Sizeof(TMidiCtlInfo), hMem );
			PctlInfo^.hMem := hMem;
		end;

		PctlInfo^.pBuffer := PBuffer;
		Pctlinfo^.hWindow := Handle;	{ Control's window handle }
		PCtlInfo^.SysexOnly := FSysexOnly;
    PCtlInfo^.FilterMTC := (msgMidiTimeCode in FMsgFilter);
    PCtlInfo^.FilterAS := (msgActiveSensing in FMsgFilter);

		FError := midiInOpen(@FMidiHandle, FDeviceId,
						DWORD(@midiHandler),
						DWORD(PCtlInfo),
						CALLBACK_FUNCTION);

		If (FError <> MMSYSERR_NOERROR) then
			{ TODO: use CreateFmtHelp to add MIDI device name/ID to message }
			raise EMidiInputError.Create(MidiInErrorString(FError));

		{ Get sysex buffers ready }
		PrepareHeaders;

		{ Add them to the input }
		AddBuffers;

		FState := misOpen;

	except
		if PBuffer <> Nil then
    begin
			CircBufFree(PBuffer);
			PBuffer := Nil;
    end;

		if PCtlInfo <> Nil then
    begin
			GlobalSharedLockedFree(PCtlInfo^.hMem, PCtlInfo);
			PCtlInfo := Nil;
    end;

    if ( FMidiHandle <> 0 ) then
    begin
      { Exception occurred after midiInOpen }
      FError := MidiInClose(FMidiHandle);
      FMidiHandle := 0;
    end;
    { Send exception to caller }
    raise;
	end;

end;

procedure TMidiInput.OpenAndStart;
begin
  Open;
  Start;
end;

{-------------------------------------------------------------------}
function TMidiInput.GetMidiEvent: TMyMidiEvent;
var
	thisItem: TMidiBufferItem;
begin
	if (FState = misOpen) and
		CircBufReadEvent(PBuffer, @thisItem) then
  begin
		Result := TMyMidiEvent.Create;
		with thisItem Do
    begin
			Result.Time := Timestamp;
			if (Sysex = Nil) then
      begin
				{ Short message }
				Result.MidiMessage := LoByte(LoWord(Data));
				Result.Data1 := HiByte(LoWord(Data));
				Result.Data2 := LoByte(HiWord(Data));
				Result.Sysex := Nil;
				Result.SysexLength := 0;
      end
			else
            	{ Long Sysex message }
      begin
				Result.MidiMessage := MIDI_BEGINSYSEX;
				Result.Data1 := 0;
				Result.Data2 := 0;
				Result.SysexLength := Sysex^.dwBytesRecorded;
				if Sysex^.dwBytesRecorded <> 0 then
        begin
					{ Put a copy of the sysex buffer in the object }
					GetMem(Result.Sysex, Sysex^.dwBytesRecorded);
					StrMove(Result.Sysex, Sysex^.lpData, Sysex^.dwBytesRecorded);
          { If you don't zero this out some MIDI drivers append new data to the old data }
          Sysex^.dwBytesRecorded := 0;
        end;

				{ Put the header back on the input buffer }
				FError := midiInPrepareHeader(FMidiHandle,Sysex,
					sizeof(TMIDIHDR));
				If Ferror = 0 then
					FError := midiInAddBuffer(FMidiHandle, Sysex, sizeof(TMIDIHDR));

				if Ferror <> MMSYSERR_NOERROR then
					raise EMidiInputError.Create(MidiInErrorString(FError));

      end;
    end;
		CircbufRemoveEvent(PBuffer);
  end
	else
		{ Device isn't open, return a nil event }
		Result := Nil;
end;

{-------------------------------------------------------------------}

function TMidiInput.GetEventCount: Word;
begin
	if FState = misOpen then
		Result := PBuffer^.EventCount
	else
		Result := 0;
end;

{-------------------------------------------------------------------}
procedure TMidiInput.ChangeDevice(const NewDeviceID: Cardinal;
  const OpenAndStartAfterChange: Boolean);
begin
  if NewDeviceID <> FDeviceID then
  begin
    Stop;
    Close;
    DeviceID := NewDeviceID;
    if OpenAndStartAfterChange then
    begin
      Open;
      Start;
    end;
  end;
end;

procedure TMidiInput.Close;
begin
	if FState = misOpen then
  begin
		FState := misClosed;

		{ MidiInReset cancels any pending output.
		Note that midiInReset causes an MIM_LONGDATA callback for each sysex
		buffer on the input, so the callback function and Midi input buffer
		should still be viable at this stage.
		All the resulting MIM_LONGDATA callbacks will be completed by the time
		MidiInReset returns, though. }
		FError := MidiInReset(FMidiHandle);
		if Ferror <> MMSYSERR_NOERROR then
			raise EMidiInputError.Create(MidiInErrorString(FError));

		{ Remove sysex buffers from input device and free them }
		UnPrepareHeaders;

		{ Close the device (finally!) }
		FError := MidiInClose(FMidiHandle);
		if Ferror <> MMSYSERR_NOERROR then
			raise EMidiInputError.Create(MidiInErrorString(FError));

		FMidiHandle := 0;

		if (PBuffer <> Nil) then
		begin
			CircBufFree( PBuffer );
			PBuffer := Nil;
		end;
  end;
end;

{-------------------------------------------------------------------}
procedure TMidiInput.Start;
begin
	if FState = misOpen then
		begin
		FError := MidiInStart(FMidiHandle);
		if Ferror <> MMSYSERR_NOERROR then
			raise EMidiInputError.Create(MidiInErrorString(FError));
		end;
end;

{-------------------------------------------------------------------}
procedure TMidiInput.Stop;
begin
	if FState = misOpen then
		begin
		FError := MidiInStop(FMidiHandle);
		if Ferror <> MMSYSERR_NOERROR then
			raise EMidiInputError.Create(MidiInErrorString(FError));
		end;
end;

procedure TMidiInput.StopAndClose;
begin
  Stop;
  Close;
end;

{-------------------------------------------------------------------}
procedure TMidiInput.MidiInput( var AMessage: TMessage );
{ Triggered by incoming message from DLL.
  Note DLL has already put the message in the queue }
begin
	case AMessage.Msg of
	mim_data:
		{ Trigger the user's MIDI input event, if they've specified one and
		we're not in the process of closing the device. The check for
		GetEventCount > 0 prevents unnecessary event calls where the user has
		already cleared all the events from the input buffer using a GetMidiEvent
		loop in the OnMidiInput event handler }
		if Assigned(FOnMIDIInput) and
      (FState = misOpen) and
      (GetEventCount > 0)
    then
			FOnMIDIInput(Self);

	mim_Overflow:	{ input circular buffer overflow }
		if Assigned(FOnOverflow) and (FState = misOpen) then
			FOnOverflow(Self);

  WM_QUERYENDSESSION:
    // Have to handle this explicitly otherwise DefWindowProc doesn't set the
    // result and app doesn't shut down when Windows shuts down or user logs off
    AMessage.Result := 1;
	end;
end;

{-------------------------------------------------------------------}
procedure Register;
begin
  RegisterComponents('MIDI I/O', [TMidiInput]);
end;

end.
