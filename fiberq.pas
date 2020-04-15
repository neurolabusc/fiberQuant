unit fiberq;

{$mode objfpc}{$H+}
// {$DEFINE GUI}
interface

uses
  Classes, SysUtils, nifti_loader;

const
  kVers = '3 March 2016';


function doFiberQuant(maskDirX, probtrackDirX: string; numROI, num_samples: integer): boolean;

implementation
{$IFDEF GUI}
uses mainui;

procedure msg(msg: string);
begin
     Form1.Memo1.Lines.Add(msg);
end;
{$ELSE}
procedure msg(msg: string);
begin
     writeln(msg);
end;
{$ENDIF}

type
 TBytes = array of byte;
 TInts = array of integer;
 TSingles = array of single;
 TDoubles = array of double;
 TImg = packed record
    mask: TBytes;//array of byte;
    prob: TSingles;//array of single;
    maskSum, probSum: double;
    maskLo, maskHi: integer;
  end;


function niiName(filename: string): string;
begin
     result := filename + '.nii.gz';
     if fileexists(result) then exit;
     result := filename + '.nii';
     if fileexists(result) then exit;
     result := '';
end;

//[ij_mean, ij_max] = fslstatsKMeanMaxSub (imgp(i,:), img(j,:));
procedure fslstatsKMeanMaxSub( var img, msk : TImg; var mean, max, meanNot0: double);
var
  i, n, nNot0: integer;
begin
     meanNot0 := 0;
     nNot0 := 0;
     mean := 0;
     max := 0;
     n := 0;
     for i := msk.maskLo to msk.maskHi do begin
         if msk.mask[i] <> 0 then begin
            n := n + 1;
            mean := mean + img.prob[i];
            if img.prob[i] > max then
               max := img.prob[i];
            if img.prob[i] <> 0 then begin
               meanNot0 := meanNot0 + img.prob[i];
               nNot0 := nNot0 + 1;
            end;
         end;
     end;
     if n > 1 then
        mean := mean / n; ;
     if nNot0 > 1 then
        meanNot0 := meanNot0 / nNot0;
end;

function loadProb(fname: string; var img: Timg; indxImg: TInts; nVoxInMasks: integer): integer;
var
  nii: TNIFTI;
  i: integer;
begin
    if (length(fname) < 1) or (not (fileexists(fname))) then exit;
    nii := TNIfTI.Create;
    nii.LoadFromFile(fname, kNiftiSmoothNone);
    result := length(nii.img);
    if result < 2 then begin
      nii.Free;
      exit;
   end;
   //compute sum of non-zero voxels
   img.probSum:=0;
   for i := 0 to (result -1) do
       if nii.img[i] > 0 then
          img.probSum := img.probSum + nii.img[i];
   //collapse
   setlength(img.prob, nVoxInMasks);
   for i := 0 to (nVoxInMasks -1) do
       img.prob[i] := nii.img[indxImg[i]];
   (*for i := 0 to (result-1) do
       if nii.img[i] = 0 then
          img.mask[i] := 0
       else
           img.mask[i] := 1; *)
   nii.Free;
end;

procedure CollapseMask(var img: Timg; indxImg: TInts; nVoxInMasks: integer);
var
  i: integer;
  maskX: TBytes;
begin
     if length(img.mask) < 1 then exit;
     maskX := Copy(img.mask, 0, MaxInt);
     setlength(img.mask,nVoxInMasks);
     img.maskLo := maxInt;
     for i := 0 to (nVoxInMasks -1) do begin
         img.mask[i] := maskX[indxImg[i]];
         if (img.mask[i] <> 0) then begin
            img.MaskHi := i;
            if img.maskLo = maxInt then
               img.maskLo := i;
         end;
     end;
     if (img.maskLo = maxInt) then begin
        msg('Error: some masks are all zeros!');
        img.maskLo := 0;
     end;
end;

function loadMask(fname: string; var img: Timg): integer;
var
  nii: TNIFTI;
  i: integer;
begin
    if (length(fname) < 1) or (not (fileexists(fname))) then exit;
    nii := TNIfTI.Create;
    nii.LoadFromFile(fname, kNiftiSmoothNone);
    result := length(nii.img);
    if result < 2 then begin
      nii.Free;
      exit;
   end;
   //create binary mask
   setlength(img.mask, result);
   for i := 0 to (result-1) do
       if nii.img[i] = 0 then
          img.mask[i] := 0
       else
           img.mask[i] := 1;
   //compute sum of non-zero voxels
   img.maskSum:=0;
   for i := 0 to (result -1) do
       img.maskSum := img.maskSum + img.mask[i];
   nii.Free;
end;

procedure saveMat(fname: string; mtx: TDoubles);
var
    f: file;
begin
     AssignFile(f, fname);
     ReWrite(f, sizeof(double));
     BlockWrite(f, mtx[0], length(mtx));
     CloseFile(f);
end; //nested saveMat

function DirPath(s: string): string;
//Make sure string ends with pathdelim, e.g. c:\dir -> c:\dir\
var
	l: integer;
begin
	l := length(s);
	if (l < 1) or (s[l] = pathdelim) then
		result := s
	else
		result := s + pathdelim;
end;

function doFiberQuant(maskDirX, probtrackDirX: string; numROI, num_samples: integer): boolean;
function mat2D(i,j: integer): integer; inline;
begin
   result := i + j * numROI;
end;
var
  mean_mat, max_mat, density_mat, fiber_count_mat: TDoubles;
  ji_sum, ij_sum, ij_mean, ij_max, ij_meanNot0, ji_mean, ji_max, ji_meanNot0, fiber_count, normalizing_factor, density: double;
  i, j, nVox, nVoxInMasks, numROIsqr : Integer;
  maskDir, probtrackDir: string;
  mNames, pNames: array of string;
  imgs: array of TImg;
  sumImg, indxImg: TInts;
  timeStart, timeLoad: QWord;
begin
   timeStart := GetTickCount64();
     result := false;
     if numROI < 2 then exit;
     maskDir := DirPath(maskDirX);
     probtrackDir := DirPath(probtrackDirX);
     if (not directoryexists(maskDir)) or (not directoryexists(probtrackDir))  then begin
        msg(format('Unable to find folders %s %s', [maskDir, probtrackDir]));
        exit;
     end;
     setlength(mNames,numROI);
     setlength(pNames,numROI);
     j := 0;
     for i := 0 to (numROI-1) do begin
         mNames[i] := niiName(maskDir+ inttostr(i+1) );
         pNames[i] := niiName(probtrackDir+ inttostr(i+1) +pathdelim + 'fdt_paths');
         if mNames[i] <> '' then
            j := j + 1;
         if ((mNames[i] <> '') and (pNames[i] = '')) or ((mNames[i] = '') and (pNames[i] <> '')) then begin
            msg(format('Unable to find masks and fibers for region %d', [i]));
            exit;
         end;
     end;
     msg(format(' FiberQuantification version '+kVers+' found %d of %d regions', [j, numROI]));
     if j < 2 then exit;
     setlength(imgs, numROI);
     nVox := 0;
     for i := 0 to (numROI-1) do begin
         j := loadMask(mNames[i], imgs[i]);
         if j = 0 then continue;
         if (nVox > 0) and (j <> nVox) then begin
            msg(format('number of voxels varies between masks %d ~= %d', [j, nVox]));
            exit;
         end;
         nVox := j;
     end;
     if (nVox < 1) then begin
        msg('Unable to load masks');
        exit;
     end;
     //create mask that only includes required items
     setlength(sumImg, nVox);
     for j := 0 to (nVox -1) do
         sumImg[j] := 0;
     for i := 0 to (numROI-1) do begin
         if length(imgs[i].mask) < nVox then continue;
         //msg(inttostr(i));
         for j := 0 to (nVox -1) do
             sumImg[j] := sumImg[j] + imgs[i].mask[j];
     end;
     nVoxInMasks := 0;
     for i := 0 to (nVox -1) do
         if sumImg[i] > 0 then
            inc(nVoxInMasks);
     msg(format(' %.1f%% voxels are in masks', [100 * nVoxInMasks/nVox]));
     if (nVoxInMasks < 1) then exit;
     setlength(indxImg, nVoxInMasks);
     nVoxInMasks := 0;
     for i := 0 to (nVox -1) do
         if sumImg[i] > 0 then begin
            indxImg[nVoxInMasks] := i;
            inc(nVoxInMasks);
         end;
     for i := 0 to (numROI-1) do
         CollapseMask(imgs[i], indxImg, nVoxInMasks);

     for i := 0 to (numROI-1) do begin
         j := loadProb(pNames[i], imgs[i], indxImg, nVoxInMasks);
         if j = 0 then continue;
         if (j <> nVox) then begin
            msg(format('number of voxels varies between probmaps %d ~= %d', [j, nVox]));
            exit;
         end;
     end;
     timeLoad := GetTickCount64();
     numROIsqr := numROI * numROI;
     setlength(mean_mat, numROIsqr);
     setlength(max_mat, numROIsqr);
     setlength(density_mat, numROIsqr);
     setlength(fiber_count_mat, numROIsqr);
     for i := 0 to numROIsqr-1 do begin
         mean_mat[i] := 0;
         max_mat[i] := 0;
         density_mat[i] := 0;
         fiber_count_mat[i] := 0;
     end;
     for i := 0 to numROI-1 do begin
         mean_mat[mat2D(i,i)] := 1;
         max_mat[mat2D(i,i)]  := 1;
         density_mat[mat2D(i,i)]  := 1;
         fiber_count_mat[mat2D(i,i)]  := 1;
     end;
     //compute stats
     for i := 0 to (numROI-2) do begin
         if (length(imgs[i].mask) < 1) or (length(imgs[i].prob) < 1) then continue;
         if (imgs[i].maskSum = 0) or (imgs[i].probSum = 0) then continue;
         for j := i+1 to (numROI-1) do begin
             if (length(imgs[j].mask) < 1) or (length(imgs[j].prob) < 1) then continue;
             if (imgs[j].maskSum = 0) or (imgs[j].probSum = 0) then continue;
             fslstatsKMeanMaxSub(imgs[i], imgs[j], ij_mean, ij_max, ij_meanNot0);
             fslstatsKMeanMaxSub(imgs[j], imgs[i], ji_mean, ji_max, ji_meanNot0);
             mean_mat[mat2D(i,j)] := ij_mean+ji_mean;
             mean_mat[mat2D(j,i)] := mean_mat[mat2D(i,j)];
             max_mat[mat2D(i,j)] := ij_max+ji_max;
             max_mat[mat2D(j,i)] := max_mat[mat2D(i,j)];
             //msg(format('%d,%d mean/max %gx%g', [i+1,j+1, mean_mat[i,j], max_mat[i,j] ]));
             ij_sum := ij_meanNot0 * imgs[j].maskSum;
             ji_sum := ji_meanNot0 * imgs[i].maskSum;
             fiber_count := ij_sum + ji_sum;
             normalizing_factor := (imgs[i].maskSum + imgs[j].maskSum) * ( num_samples + 1 );
             density := fiber_count/normalizing_factor;
             //msg(format('%d,%d mean %gx%g fiber_count %g density %g', [i+1,j+1, ij_meanNot0, ji_meanNot0, fiber_count, density]));
             density_mat[mat2D(i,j)] := density;
             density_mat[mat2D(j,i)] := density;
             fiber_count_mat[mat2D(i,j)] := fiber_count;
             fiber_count_mat[mat2D(j,i)] := fiber_count;
         end;
     end; //for i: each row
     //write results
     {$IFNDEF ENDIAN_LITTLE}
     error - byte-swap data! we require LITTLE ENDIAN floats!
     {$ENDIF}
     savemat(maskDir+'mean.mtx',  mean_mat);
     savemat(maskDir+'max.mtx',  max_mat);
     savemat(maskDir+'density.mtx',  density_mat);
     savemat(maskDir+'fiber_count.mtx',  fiber_count_mat);
     msg(format(' fiber quantification required %dms (loading=%d, calculation=%d) ', [GetTickCount64()- timeStart, timeLoad-timeStart, GetTickCount64()- timeLoad]) );
     result := true;
end;


end.

