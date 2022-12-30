{
  Author: Niels A.D
  Project: Lape (https://github.com/nielsAD/lape)
  License: GNU Lesser GPL (http://www.gnu.org/licenses/lgpl.html)

  Bytecode disassembler.
}
unit lpdisassembler;

{$I lape.inc}
{$IFNDEF FPC}
  {$UNDEF Lape_Inline}
{$ENDIF}

interface

uses
  Classes, SysUtils,
  lptypes, lpvartypes;

type
  TLapeDisassemblerPointerMap = {$IFDEF FPC}specialize{$ENDIF} TLapeStringMap<string>;

procedure DisassembleCode(ACode: PByte; PointerNames: TLapeDisassemblerPointerMap); overload;
procedure DisassembleCode(ACode: PByte; PointerNames: TLapeCompilerBase); overload;
procedure DisassembleCode(ACode: PByte; PointerNames: TLapeDeclArray = nil); overload;

implementation

uses
  lpmessages, lpinterpreter, lpeval, lputils;

procedure DisassembleCode(ACode: PByte; PointerNames: TLapeDisassemblerPointerMap);
var
  FCode: PByte;
  FCodeBase: PByte;
  {$IFDEF Lape_EmitPos}p: TDocPos;{$ENDIF}

  function IntToStr(i: Int64): string; overload;
  begin
    Result := SysUtils.IntToStr(i);
  end;

  function IntToStr(p: Pointer): string; overload;
  var s: string;
  begin
    if (p = nil) then
      Result := 'nil'
    else
    begin
      s := IntToHex(PtrUInt(p), 0);
      if (PointerNames <> nil) and PointerNames.ExistsKey(lpString(s)) then
        Result := PointerNames[lpString(s)]
      else
        Result := '$' + s;
    end;
  end;

  procedure _WriteLn(s: string); overload; {$IFDEF Lape_Inline}inline;{$ENDIF}
  begin
    WriteLn('$', IntToHex(FCode - FCodeBase, 8), ' :: ', s);
  end;

  procedure _WriteLn(s: string; args: array of const); overload;
  begin
    _WriteLn(Format(s, args));
  end;

  procedure DoCheckInternal; {$IFDEF Lape_Inline}inline;{$ENDIF}
  begin
    _WriteLn('IsInternal');
    _WriteLn('IncStack %d', [SizeOf(EvalBool) - SizeOf(Pointer)]);
    Inc(FCode, ocSize);
  end;

  procedure DoGetExceptionMessage; {$IFDEF Lape_Inline}inline;{$ENDIF}
  begin
    _WriteLn('GetExceptionMessage');
    _WriteLn('IncStack %d', [SizeOf(ShortString)]);
    Inc(FCode, ocSize);
  end;

  procedure DoGetExceptionLocation;
  begin
    _WriteLn('GetExceptionLocation');
    _WriteLn('IncStack %d', [SizeOf(Pointer)]);
    Inc(FCode, ocSize);
  end;

  procedure DoGetCallerLocation;
  begin
    _WriteLn('GetCallerLocation');
    _WriteLn('IncStack %d', [SizeOf(Pointer)]);
    Inc(FCode, ocSize);
  end;

  procedure DoInitStackLen; {$IFDEF Lape_Inline}inline;{$ENDIF}
  begin
    _WriteLn('InitStackLen %d', [PStackOffset(PtrUInt(FCode) + ocSize)^]);
    Inc(FCode, SizeOf(TStackOffset) + ocSize);
  end;

  procedure DoInitVarLen; {$IFDEF Lape_Inline}inline;{$ENDIF}
  begin
    _WriteLn('InitVarStackLen %d', [PStackOffset(PtrUInt(FCode) + ocSize)^]);
    Inc(FCode, SizeOf(TStackOffset) + ocSize);
  end;

  procedure DoInitStack; {$IFDEF Lape_Inline}inline;{$ENDIF}
  begin
    _WriteLn('InitStack %d', [PStackOffset(PtrUInt(FCode) + ocSize)^]);
    Inc(FCode, SizeOf(TStackOffset) + ocSize);
  end;

  procedure DoGrowStack; {$IFDEF Lape_Inline}inline;{$ENDIF}
  begin
    _WriteLn('GrowStack %d', [PStackOffset(PtrUInt(FCode) + ocSize)^]);
    Inc(FCode, SizeOf(TStackOffset) + ocSize);
  end;

  procedure DoExpandVar; {$IFDEF Lape_Inline}inline;{$ENDIF}
  begin
    _WriteLn('ExpandVarStack %d', [PStackOffset(PtrUInt(FCode) + ocSize)^]);
    Inc(FCode, SizeOf(TStackOffset) + ocSize);
  end;

  procedure DoExpandVarAndInit; {$IFDEF Lape_Inline}inline;{$ENDIF}
  begin
    _WriteLn('ExpandVarStackAndInit %d', [PStackOffset(PtrUInt(FCode) + ocSize)^]);
    Inc(FCode, SizeOf(TStackOffset) + ocSize);
  end;

  procedure DoGrowVar; {$IFDEF Lape_Inline}inline;{$ENDIF}
  begin
    _WriteLn('GrowVarStack %d', [PStackOffset(PtrUInt(FCode) + ocSize)^]);
    Inc(FCode, SizeOf(TStackOffset) + ocSize);
  end;

  procedure DoGrowVarAndInit; {$IFDEF Lape_Inline}inline;{$ENDIF}
  begin
    _WriteLn('GrowVarStackAndInit %d', [PStackOffset(PtrUInt(FCode) + ocSize)^]);
    Inc(FCode, SizeOf(TStackOffset) + ocSize);
  end;

  procedure DoPopVar; {$IFDEF Lape_Inline}inline;{$ENDIF}
  begin
    _WriteLn('PopVarStack');
    Inc(FCode, ocSize);
  end;

  procedure DoPopStackToVar; {$IFDEF Lape_Inline}inline;{$ENDIF}
  begin
    with POC_PopStackToVar(PtrUInt(FCode) + ocSize)^ do
    begin
      _WriteLn('PopStackToVar %d %d', [Size, VOffset]);
      _WriteLn('DecStackPos %d', [Size]);
    end;
    Inc(FCode, ocSize + SizeOf(TOC_PopStackToVar));
  end;

  procedure DoPopVarToStack; {$IFDEF Lape_Inline}inline;{$ENDIF}
  begin
    with POC_PopStackToVar(PtrUInt(FCode) + ocSize)^ do
    begin
      _WriteLn('PopVarToStack %d %d', [Size, VOffset]);
      _WriteLn('IncStackPos %d', [Size]);
    end;
    Inc(FCode, ocSize + SizeOf(TOC_PopStackToVar));
  end;

  procedure DoJmpVar; {$IFDEF Lape_Inline}inline;{$ENDIF}
  begin
    _WriteLn('JmpVar');
    Inc(FCode, ocSize);
  end;

  procedure DoJmpSafe; {$IFDEF Lape_Inline}inline;{$ENDIF}
  begin
    _WriteLn('JmpSafe $%x', [PCodePos(PtrUInt(FCode) + ocSize)^]);
    Inc(FCode, ocSize + SizeOf(TCodePos));
  end;

  procedure DoJmpSafeR; {$IFDEF Lape_Inline}inline;{$ENDIF}
  begin
    _WriteLn('JmpSafeR $%x', [PtrInt(FCode - FCodeBase) + PCodeOffset(PtrUInt(FCode) + ocSize)^]);
    Inc(FCode, ocSize + SizeOf(TCodeOffset));
  end;

  procedure DoIncTry; {$IFDEF Lape_Inline}inline;{$ENDIF}
  begin
    with POC_IncTry(PtrUInt(FCode) + ocSize)^ do
      if (JmpFinally = Try_NoFinally) then
        _WriteLn('IncTry $%x (NoFinally)', [PtrInt(FCode - FCodeBase) + Jmp])
      else if (JmpFinally = Try_NoExcept) then
        _WriteLn('IncTry $%x (NoExcept)',  [PtrInt(FCode - FCodeBase) + Jmp])
      else
        _WriteLn('IncTry $%x $%x', [PtrInt(FCode - FCodeBase) + Jmp, PtrInt(FCode - FCodeBase) + Jmp + Int32(JmpFinally)]);
    Inc(FCode, ocSize + SizeOf(TOC_IncTry));
  end;

  procedure DoDecTry; {$IFDEF Lape_Inline}inline;{$ENDIF}
  begin
    _WriteLn('DecTry');
    Inc(FCode, ocSize);
  end;

  procedure DoEndTry; {$IFDEF Lape_Inline}inline;{$ENDIF}
  begin
    _WriteLn('EndTry');
    Inc(FCode, ocSize);
  end;

  procedure DoCatchException; {$IFDEF Lape_Inline}inline;{$ENDIF}
  begin
    _WriteLn('CatchException');
    Inc(FCode, ocSize);
  end;

  procedure DoReRaiseException; {$IFDEF Lape_Inline}inline;{$ENDIF}
  begin
    _WriteLn('ReRaiseException');
    Inc(FCode, ocSize);
  end;

  procedure DoDecCall; {$IFDEF Lape_Inline}inline;{$ENDIF}
  begin
    _WriteLn('DecCall');
    Inc(FCode, ocSize);
  end;

  procedure DoDecCall_EndTry; {$IFDEF Lape_Inline}inline;{$ENDIF}
  begin
    _WriteLn('DecCall_EndTry');
    Inc(FCode, ocSize);
  end;

  {$I lpdisassembler_doinvoke.inc}
  {$I lpdisassembler_dojump.inc}
  {$I lpdisassembler_doeval.inc}

begin
  FCode := ACode;
  FCodeBase := ACode;

  {$IFDEF Lape_EmitPos}
  p.Line := 0;
  p.Col := 0;
  {$ENDIF}

  try
    while True do
    begin
      {$IFDEF Lape_EmitPos}
      with PDocPos(PtrUInt(FCode) + SizeOf(opCodeType))^ do
        if (p.FileName <> FileName) or (p.Line <> Line) or (p.Col <> Col) then
        begin
          p.FileName := FileName;
          p.Line := Line;
          p.Col := Col;
          _WriteLn('--> File "'+string(FileName)+'", Line '+IntToStr(Line)+', Col '+IntToStr(Col));
        end;
      {$ENDIF}
      {$I lpinterpreter_opcodecase.inc}
    end;
  except
    on E: Exception do
      LapeExceptionFmt(lpeRuntime, [E.Message] {$IFDEF Lape_EmitPos}, PDocPos(PtrUInt(FCode) + SizeOf(opCodeType))^ {$ENDIF});
  end;
end;

procedure Disassemble__EvalProcs(pMap: TLapeDisassemblerPointerMap);
var
  op: EOperator;
  t1, t2: ELapeBaseType;
  proc: TLapeEvalProc;
begin
  Assert(pMap <> nil);
  for op := Low(EOperator) to High(EOperator) do
  begin
    if (op_name[op] = '') then
      Continue;

    for t1 := High(ELapeBaseType) downto Low(ELapeBaseType)  do
      for t2 := High(ELapeBaseType) downto Low(ELapeBaseType) do
      begin
        proc := getEvalProc(op, t1, t2);
        if ValidEvalFunction(proc) then
          if (t1 = ltUnknown) then
            pMap[lpString(IntToHex(PtrUInt({$IFNDEF FPC}@{$ENDIF}proc), 0))] := 'lpe'+string(op_name[op])
          else if (t2 = ltUnknown) then
            pMap[lpString(IntToHex(PtrUInt({$IFNDEF FPC}@{$ENDIF}proc), 0))] := 'lpe'+string(LapeTypeToString(t1))+'_'+string(op_name[op])
          else
            pMap[lpString(IntToHex(PtrUInt({$IFNDEF FPC}@{$ENDIF}proc), 0))] := 'lpe'+string(LapeTypeToString(t1))+'_'+string(op_name[op]+'_'+LapeTypeToString(t2));
      end;
  end;
end;

procedure Disassemble__PointerMap(v: TLapeGlobalVar; AName: lpString; Compiler: TLapeCompilerBase; var Arg);
begin
  if (AName = '') then
    TLapeDisassemblerPointerMap(Arg)[lpString(IntToHex(PtrUInt(v.Ptr), 0))] := string(v.AsString)
  else
    TLapeDisassemblerPointerMap(Arg)[lpString(IntToHex(PtrUInt(v.Ptr), 0))] := string(AName);
end;

procedure DisassembleCode(ACode: PByte; PointerNames: TLapeCompilerBase);
var
  pMap: TLapeDisassemblerPointerMap;
begin
  pMap := TLapeDisassemblerPointerMap.Create('', dupIgnore, True);
  try
    Disassemble__EvalProcs(pMap);
    TraverseGlobals(PointerNames, @Disassemble__PointerMap, pMap);
    DisassembleCode(ACode, pMap);
  finally
    pMap.Free();
  end;
end;

procedure DisassembleCode(ACode: PByte; PointerNames: TLapeDeclArray = nil);
var
  pMap: TLapeDisassemblerPointerMap;
  i: Integer;
begin
  pMap := TLapeDisassemblerPointerMap.Create('', dupIgnore, True);
  try
    Disassemble__EvalProcs(pMap);

    for i := 0 to High(PointerNames) do
      if (PointerNames[i].Name = '') and (PointerNames[i] is TLapeGlobalVar) then
        pMap[lpString(IntToHex(PtrUInt(TLapeGlobalVar(PointerNames[i]).Ptr), 0))] := string(TLapeGlobalVar(PointerNames[i]).AsString)
      else if (PointerNames[i] is TLapeGlobalVar) then
        pMap[lpString(IntToHex(PtrUInt(TLapeGlobalVar(PointerNames[i]).Ptr), 0))] := string(PointerNames[i].Name)
      else
        pMap[lpString(IntToHex(PtrUInt(PointerNames[i]), 0))] := string(PointerNames[i].Name);

    DisassembleCode(ACode, pMap);
  finally
    pMap.Free();
  end;
end;

end.

