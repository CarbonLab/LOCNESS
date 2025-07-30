function write_map(mat_rgb, liste_couleurs, varname, st)

% WRITE_MAP: built off of Monique's "Write_Layermap" function
% 
% write_layermap(mat_rgb,liste_couleurs,varargin)
% 'point' or 'polygon' (default polygon)
% 'experiment' (default from rep_kml_global)
%
global rep_kml_global kml_global
kml_global = varname ;

% filename=[rep_kml_global,kml_global,'.layer.map']; % can use this if global
% variables start working again

filename=[rep_kml_global,varname,'.layer.map'];

arg.style = st;
arg.experiment = 'assets' ;

if max(max(mat_rgb))<=2, mat_rgb=mat_rgb*255; end, mat_rgb=round(mat_rgb);
fid=fopen(filename,'w');
fprintf(fid,'  LAYER\n');
fprintf(fid,['    NAME ''',arg.experiment,':',kml_global,'''\n']);
fprintf(fid,['    TYPE ',upper(arg.style),'\n']);
fprintf(fid,'    STATUS ON\n');
fprintf(fid,'\n');
fprintf(fid,'    CONNECTIONTYPE OGR\n');
fprintf(fid,['    CONNECTION ''','/data/mapserver/mapfiles/assets/',kml_global,'.kml'' \n']);
fprintf(fid,'\n');
fprintf(fid,'    DATA "Layer #0"\n');
fprintf(fid,'    LABELITEM "name"\n');
fprintf(fid,'\n');
%  CONNECTION '/data/mapserver/mapfiles/assets/rhodamine.kml
for i=1:size(mat_rgb,1)

	fprintf(fid,'    CLASS\n');
	fprintf(fid,'    NAME DOESNTMATTER \n'); 
	fprintf(fid,['        EXPRESSION (''[name]'' == ''',liste_couleurs{i},''')\n']);
	fprintf(fid,'        STYLE \n');
	fprintf(fid,['            COLOR ',num2str(mat_rgb(i,1)),' ',num2str(mat_rgb(i,2)),' ',num2str(mat_rgb(i,3)),'\n']);
	fprintf(fid,['            OUTLINECOLOR ',num2str(mat_rgb(i,1)),' ',num2str(mat_rgb(i,2)),' ',num2str(mat_rgb(i,3)),'\n']);
	switch arg.style
		case 'polygon'
			fprintf(fid,'            WIDTH 1 \n');
		case 'point'
			fprintf(fid,'            SYMBOL "circle" \n');
			fprintf(fid,'            SIZE 10 \n');
	end
	fprintf(fid,'        END \n');
	fprintf(fid,'    END\n');
	fprintf(fid,'\n');

end

fprintf(fid,'    CLASS\n');
fprintf(fid,['      NAME   "',arg.experiment,':',kml_global,'"\n']);
fprintf(fid,['      KEYIMAGE   "','assets/','legend-icons/',kml_global,'.png"\n']);
fprintf(fid,'    END\n');
fprintf(fid,'\n'); 
fprintf(fid,'    PROJECTION\n');
fprintf(fid,'    ''proj=longlat''\n');
fprintf(fid,'    ''datum=WGS84''\n');
fprintf(fid,'    ''no_defs''\n');
fprintf(fid,'    END\n');
fprintf(fid,'\n');
fprintf(fid,'    METADATA\n');
fprintf(fid,['      ''wms_title''           ''',arg.experiment,':',kml_global,'''\n']);
fprintf(fid,['      ''wms_name''            ''',arg.experiment,':',kml_global,'''\n']);
fprintf(fid,'      ''wms_onlineresource''  ''http:/localhost/cgi-bin/mapserv?map=/data/mapserver/mapfiles/odss.map''\n');
fprintf(fid,'      ''wms_server_version''  ''1.1.0''\n');
fprintf(fid,'      ''wms_srs''             ''EPSG:4326''\n');
fprintf(fid,'      ''wms_format''          ''image/png''\n');
fprintf(fid,'      ''wms_transparent''     ''true''\n');
fprintf(fid,'    END\n');
fprintf(fid,'\n');
fprintf(fid,'END');

fclose(fid);
