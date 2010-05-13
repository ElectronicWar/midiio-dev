(**
 * MidiKeyPatchArray.pas v2010-05r1
 *
 *    Author: Manuel Kröber
 *      Mail: manuel.kroeber@googlemail.com
 *       Web: http://saso-labs.com/
 * Copyright: (c)2009-2010 by Manuel Kröber
 *
 * This source is licensed under the Mozilla Public License 1.1 (MPL 1.1).
 * See LICENSE file or http://www.opensource.org/licenses/mozilla1.1.php for
 * a reference.
 *
 * Description:
 * Provides additional functions for MIDI stuff
 **)

unit MidiKeyPatchArray;

interface

uses MidiDefs, MMsystem;

type
  // For patch caching.
  // http://msdn.microsoft.com/en-us/library/dd757122(VS.85).aspx
  // Each array element represents a key with 16 midi channels (word = 16 bit).
  // The bit represents on or off of the channel for this key for called
  // command, e.g. drum patch caching. Defined KEYARRAY and PATCHARRAY are equal
  TKeyPatchArray = array[0..(MIDIPATCHSIZE-1)] of Word;

  // Used to easy enable channels in given patch number in a PatchArray.
  // Use ChannelsToEnable = [] or omit to disable all channels from given patch.
  function SetPatchChannels(var PatchArray: TKeyPatchArray; const PatchNumber: Byte;
    const ChannelsToEnable: TMidiChannels = []): Boolean;

implementation

function SetPatchChannels(var PatchArray: TKeyPatchArray; const PatchNumber: Byte;
  const ChannelsToEnable: TMidiChannels): Boolean;
var
  CurChannel: TMidiChannel;
begin
  if high(PatchArray) < PatchNumber then
  begin
    Result := True;
    PatchArray[PatchNumber] := 0; // Reset

    for CurChannel in ChannelsToEnable do
    begin
      PatchArray[PatchNumber] := PatchArray[PatchNumber] or
        (1 shl CurChannel);
    end;
  end
  else
  begin
    Result := False;
  end;
end;

end.
