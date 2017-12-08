unit lpvartypes_class;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  lpvartypes, lptypes;

type
  TLapeType_Class = class(TLapeType_Pointer)
  public
    function EvalRes(Op: EOperator; Right: TLapeGlobalVar; Flags: ELapeEvalFlags): TLapeType; override;
    function EvalRes(Op: EOperator; Right: TLapeType = nil; Flags: ELapeEvalFlags = []): TLapeType; override;
    function Eval(Op: EOperator; var Dest: TResVar; Left, Right: TResVar; Flags: ELapeEvalFlags; var Offset: Integer; Pos: PDocPos = nil): TResVar; override;
  end;

implementation

function TLapeType_Class.EvalRes(Op: EOperator; Right: TLapeGlobalVar; Flags: ELapeEvalFlags): TLapeType;
begin
  Result := nil;
  if (op = op_Dot) then
    Result := FPType.EvalRes(op, Right, Flags);
  if (Result = nil) then
    Result := inherited EvalRes(Op, Right, Flags);
end;

function TLapeType_Class.EvalRes(Op: EOperator; Right: TLapeType = nil; Flags: ELapeEvalFlags = []): TLapeType;
begin
  Result := nil;
  if (op = op_Dot) then
    Result := FPType.EvalRes(op, Right, Flags);
  if (Result = nil) then
    Result := inherited EvalRes(Op, Right, Flags);
end;

function TLapeType_Class.Eval(Op: EOperator; var Dest: TResVar; Left, Right: TResVar; Flags: ELapeEvalFlags; var Offset: Integer; Pos: PDocPos = nil): TResVar;
begin
  if (op = op_Dot) and ValidFieldName(Right) and (not HasSubDeclaration(PlpString(Right.VarPos.GlobalVar.Ptr)^, bTrue)) then
    Result := PType.Eval(op_Dot, Dest, Eval(op_Deref, Dest, Left, NullResVar, [], Offset, Pos), Right, Flags, Offset, Pos)
  else
    Result := inherited Eval(Op, Dest, Left, Right, Flags, Offset, Pos);
end;

end.

