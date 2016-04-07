program testproject;

uses
  unit1, unit2,
  formunit3 {fmFormUnit3},
  unit4 in 'subfolder\unit4.pas', // unit6
  absent_unit,
  (*unit7, unit8*)
  interface_only_unit,
  unit5, (**)unit6;

begin
end.
