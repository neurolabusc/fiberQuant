program fq;
{$MODE DELPHI}{$H+}
uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
SysUtils, fiberq;

//const kVers = 'ss';

procedure WriteHelp;
var
	ExeName: string;
begin
	ExeName := paramstr(0);
	writeln('Usage: '+ ExeName+ ' maskDir probtrackDir numROI num_samples');
	writeln(' Version '+kVers);
	writeln(' Example ');
	{$IFDEF UNIX}
	writeln(' '+ExeName+' "/Users/u/masks" "/Users/u/probtrackx" 189 5000');
	{$ELSE}
	writeln(' '+ExeName+' "c:\dir\masks" "c:\dir\probtrackx" 189 5000');
	{$ENDIF}
end;

procedure RunFQ;
//doFiberQuant(maskDir, probtrackDir: string; numROI, num_samples: integer): boolean;
var
	maskDir, probtrackDir: string;
	numROI, num_samples: integer;
begin
	maskDir  := Paramstr(1);
	probtrackDir  := Paramstr(2);
	numROI := StrToInt(Paramstr(3));
	num_samples := StrToInt(Paramstr(4));
	doFiberQuant(maskDir, probtrackDir, numROI, num_samples)

end;

begin
	if paramcount < 4 then
		WriteHelp
	else
		RunFQ;
end.