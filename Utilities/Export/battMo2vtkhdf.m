function battMo2vtkhdf(model,states,outputfile)

    % %% Get array dimensions from model
    % nts = numel(states);
    % nc = model.G.cells.num;
    % nc_elyte = model.Electrolyte.G.cells.num;
    % nc_ne = model.NegativeElectrode.G.cells.num;
    % nc_pe = model.PositiveElectrode.G.cells.num;
    % nc_neam = model.NegativeElectrode.ActiveMaterial.G.cells.num;
    % nc_peam = model.PositiveElectrode.ActiveMaterial.G.cells.num;
    % N_ne = model.NegativeElectrode.ActiveMaterial.SolidDiffusion.N;
    % N_pe = model.PositiveElectrode.ActiveMaterial.SolidDiffusion.N;


    [points, cells] = getVTKPointsCells(model.G);

    fname = outputfile;

    h5create(fname,'/VTKHDF/PointData/Points',size(points));
    h5create(fname,'/VTKHDF/CellData/Cells',size(cells));
    h5create(fname,'/VTKHDF/FieldData/C',size(points));
   
    h5writeatt(fname,'/VTKHDF',"Version",[1,0])
    h5writeatt(fname,'/VTKHDF',"Type","UnstructuredGrid")

    h5write(fname,'/VTKHDF/PointData/Points',points);
    h5write(fname,'/VTKHDF/CellData/Cells',cells);

