**free
ctl-opt option(*nodebugio:*srcstmt:*nounref) decedit('0,');

dcl-f httpgetspd workstn indds(indicators);

dcl-ds indicators;
  exit     ind pos(03);
  descrip2 ind pos(40);
  descrip3 ind pos(41);
end-ds;

dcl-ds locRec  likerec(loc_fmt:*output);
dcl-ds currRec likerec(curr_fmt:*all);

dcl-ds location qualified;
  name        varchar(50);
  country     varchar(50);
  region      varchar(50);
  lat         varchar(50);
  lon         varchar(50);
  timezone_id varchar(50);
  localtime   varchar(50);
end-ds;

dcl-ds current qualified;
  temperature              zoned(3);
  num_weather_descriptions zoned(1);
  weather_descriptions     varchar(100) dim(3);
  wind_speed               zoned(3);
  wind_degree              zoned(3);
  wind_dir                 varchar(3);
  pressure                 zoned(4);
  precip                   zoned(3);
  humidity                 zoned(3);
  cloudcover               zoned(3);
  feelslike                zoned(3);
  uv_index                 zoned(3);
  visibility               zoned(3);
end-ds;

dcl-s response  sqltype(clob:10000) ccsid(1208);
// El compilador generará esto:
//   dcl-ds response
//     response_len  uns(10);
//     response_data char(10000) ccsid(1208);
//   end-ds;

dcl-s ifsFile1 sqltype(clob_file)ccsid(1208);
// El compildor generará esto:
//  dcl-ds ifsFile inz;
//     ifsFile1_nl   uns(10);
//     ifsFile1_dl   uns(10);
//     ifsFile1_fo   uns(10);
//     ifsFile1_name char(255);
//  end-ds;
//
// _name = Nombre del archivo (ruta completa)
// _nl   = Longitud del nombre del archivo (ruta completa)
// _fo   = Operación a realizar en el archivo (ver constantes más abajo)
// _dl   = No usado
//
// El compilador aï¿½ade estas constantes también:
//   SQFRD  = 2  = Lee del archivo.
//   SQFCRT = 4  = Crea un archivo en el caso de que no exista, en caso contrario lanza un error.
//   SQFOVR = 8  = Sobrescribe el archivo si existe, en caso contrario crea uno nuevo.
//   SQFAPP = 16 = Aï¿½ade al final del archivo si existe, en caso contrario crea uno nuevo.

dcl-s url varchar(1000);

exec sql set option commit = *none, closqlcsr = *endmod;

pgmname = 'HTTPGETSP';

// Sustituya las xxx... por su propia api key. Es gratuita y la puede obtener de https://weatherstack.com
url='http://api.weatherstack.com/current?access_key=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx&query=madrid';

// http_get devuelve un CLOB de hasta 2GB con un CCSID de 1208. En este programa se usa un CLOB de 10KB
exec sql
  values (qsys2.http_get(:url))
    into :response;

ifsFile1_name = '/home/asalcedo/common/iberia/weather_http_get.json';
ifsFile1_nl   = %len(%trim(ifsFile1_name));
ifsFile1_fo   = SQFOVR;

// Guarda el contenido de response en el archivo CLOB
exec sql set :ifsFile1 = :response;

data-into location %data(response_data: 'allowextra=yes path=json/location')
                   %parser('YAJLINTO':'{"document_name":"json" }');

data-into current %data(response_data: 'allowextra=yes path=json/current countprefix=num_')
                  %parser('YAJLINTO':'{"document_name":"json" }');

write header;
write fkeys;

eval-corr locRec = location;
locRec.timezone = location.timezone_id;

eval-corr currRec = current;
currRec.temp = current.temperature;
currRec.desc1 = current.weather_descriptions(1);
if current.num_weather_descriptions >= 2;
  descrip2 = *on;
  currRec.desc2 = current.weather_descriptions(2);
  if current.num_weather_descriptions = 3;
    descrip3 = *on;
    currRec.desc3 = current.weather_descriptions(3);
  endif;
endif;
currRec.winddegree = current.wind_degree;

dow not exit;
  write loc_fmt locRec;
  exfmt curr_fmt currRec;
enddo;

*inlr = *on; 