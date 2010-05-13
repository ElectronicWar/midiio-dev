{ $Header: /MidiComp/MULTIMNP.PAS 2     10/06/97 7:33 Davec $ }


(**
 * VALID FOR ALL MODIFICATIONS TO ORIGINAL SOURCE
 * MultiNMP.pas v2010-05r1
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
 

{ This demo shows how MIDI input devices can be created at runtime.
  It creates one MidiInput component for each physical MIDI input device
  on the system, and uses a common input handler procedure to display
  the input data, including the name of the input device. }

unit MultiNMP;

interface

uses
  SysUtils, WinTypes, WinProcs, Messages, Classes, Graphics, Controls,
  Forms, Dialogs, MMSystem, StdCtrls, MIDIIn, MidiOut, MidiType, ExtCtrls,
  Menus, Monprocs;

type
  TForm1 = class(TForm)
	lstLog: TListBox;
	pnlColumnHeading: TPanel;
	MainMenu1: TMainMenu;
	File1: TMenuItem;
	mnuExit: TMenuItem;
	procedure MIDIInput1MidiInput(Sender: TObject);
	procedure LogMessage(devName: String; ThisEvent:TMyMidiEvent);
	procedure FormCreate(Sender: TObject);
	procedure FormResize(Sender: TObject);
	procedure FormClose(Sender: TObject; var Action: TCloseAction);
	procedure mnuExitClick(Sender: TObject);
  private
	logItemMax: Integer;
	MidiInControls: TList;
  public
	{ Public declarations }
  end;

var
  Form1: TForm1;
  inh: HMidiIn;

implementation

{$R *.DFM}


procedure TForm1.LogMessage(devName: String; ThisEvent: TMyMidiEvent);
{ Logging MIDI messages with a Windows list box is rather slow and ugly,
  but it makes the example very simple.  If you need a faster and less
  flickery log you could port the rest of Microsoft's MIDIMON.C example. }
begin
	if logItemMax > 0 then
		begin
		With lstLog.Items do
			begin
			if Count >= logItemMax then
				Delete(0);
			Add(Copy(devName,1,7) + ' ' + MonitorMessageText(ThisEvent));
			end;
		end;
end;

procedure TForm1.MIDIInput1MidiInput(Sender: TObject);
var
	thisEvent: TMyMidiEvent;
begin
	with (Sender As TMidiInput) do
		begin
		while (MessageCount > 0) do
			begin

			{ Get the event as an object }
			thisEvent := GetMidiEvent;

			{ Log it, using the name of the current device }
			LogMessage(Copy(ProductName,1,7), thisEvent);

      { Event was dynamically created by GetMidiEvent so must
				free it here }
			thisEvent.Free;

			end;
		end;
end;

procedure TForm1.FormCreate(Sender: TObject);
var
	testDeviceID: Word;
	thisControl: TMidiInput;
begin
	{ Create and open one MIDI input control for each installed MIDI input device }
	midiInControls := TList.Create;
	if midiInGetNumDevs > 0 then
		 for testDeviceID := 0 To (midiInGetNumDevs-1) do
			 begin
			 thisControl := TMidiInput.Create(Self);
			 thisControl.DeviceID := testDeviceID;
			 thisControl.OnMidiInput := Form1.MIDIInput1MidiInput;
			 thisControl.Open;
			 thisControl.Start;
			 MidiInControls.Add(thisControl);
			 end;
end;

procedure TForm1.FormResize(Sender: TObject);
const
	logMargin = 8;
begin
	{ Set maximum items that can be stored in the list box without scrolling }
	if lstLog.ItemHeight > 0 then
		begin
		logItemMax := (lstLog.Height div lstLog.ItemHeight)-1;
		{ If there are currently more items than the max, remove them
		  otherwise the list will have scrollbars when resized }
		with lstLog.Items do
			begin
			while (Count >= logItemMax) and (Count > 0) do
				Delete(0);
				end;
			end
	else
		logItemMax := 0;
end;

procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
var
	controlCtr: Integer;
begin
	{ This is not strictly necessary since the objects close themselves
	  when the form containing them is destroyed }
	with MidiInControls do
		if Count > 0 then
			for controlCtr := 0 to Count-1 do
				TMidiInput(Items[controlCtr]).Free;
end;

procedure TForm1.mnuExitClick(Sender: TObject);
begin
	Application.Terminate;
end;


end.
