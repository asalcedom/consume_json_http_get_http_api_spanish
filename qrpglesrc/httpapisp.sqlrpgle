**free
ctl-opt option(*nodebugio:*srcstmt:*nounref) decedit('0,') bnddir('HTTPAPI':'YAJL');

dcl-f httpgetspd workstn indds(indicators);

/include qgpl/qrpglesrc,httpapi_h
/include yajl/qrpglesrc,yajl_h

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

dcl-s jsonString varchar(100000) ccsid(1208);

dcl-s response   sqltype(clob:10000) ccsid(1208);
// El compilador generará esto:
//   dcl-ds response
//     response_len  uns(10);
//     response_data char(10000) ccsid(1208);
//   end-ds;

dcl-s ifsFile1   sqltype(clob_file)ccsid(1208);
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
// El compilador añade estas constantes también:
//   SQFRD  = 2  = Lee del archivo.
//   SQFCRT = 4  = Crea un archivo en el caso de que no exista, en caso contrario lanza un error.
//   SQFOVR = 8  = Sobrescribe el archivo si existe, en caso contrario crea uno nuevo.
//   SQFAPP = 16 = Añade al final del archivo si existe, en caso contrario crea uno nuevo.

dcl-s url       varchar(1000);
dcl-s docNode   like(yajl_val);
dcl-s node      like(yajl_val);
dcl-s val       like(yajl_val);
dcl-s descrip   like(yajl_val);
dcl-s key       varchar(50);
dcl-s errMsg    varchar(500);
dcl-s i         int(10);
dcl-s j         int(10);

exec sql set option commit = *none, closqlcsr = *endmod;

pgmname = 'HTTPAPISP';

// Sustituya las xxx... por su propia api key. Es gratuita y la puede obtener de https://weatherstack.com
url='http://api.weatherstack.com/current?access_key=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx&query=madrid';

// http_string devuelve un varchar(100000)
jsonString = http_string('GET':url);

response_data = jsonString;
response_len  = %len(jsonString);

ifsFile1_name = '/home/asalcedo/common/iberia/weather_http_string.json';
ifsFile1_nl   = %len(%trim(ifsFile1_name));
ifsFile1_fo   = SQFOVR;

// Guarda el contenido de response en el archivo CLOB
exec sql set :ifsFile1 = :response;

// Carga el JSON completo
docNode = yajl_string_load_tree(jsonString:errMsg);
if errMsg <> '';
  snd-msg 'Error cargando el JSON en formato string.' %target(*self:2);
  snd-msg errMsg %target(*self:2);
endif;

// Selecciona el objeto 'location' y le procesa dentro de un bucle
//  extrayendo sólo la info de las etiquetas que interesan
node = yajl_object_find(docNode:'location');
i=0;
dow yajl_object_loop(node:i:key:val);
  select key;
    when-is 'name';
      location.name = yajl_get_string(val);
    when-is 'country';
      location.country = yajl_get_string(val);
    when-is 'region';
      location.region = yajl_get_string(val);
    when-is 'lat';
      location.lat = yajl_get_string(val);
    when-is 'lon';
      location.lon = yajl_get_string(val);
    when-is 'timezone_id';
      location.timezone_id = yajl_get_string(val);
    when-is 'localtime';
      location.localtime = yajl_get_string(val);
  endsl;
enddo;

// Selecciona el objeto 'current' y le procesa dentro de un bucle
//  extrayendo sólo la info de las etiquetas que interesan
node = yajl_object_find(docNode:'current');
i = 0;
dow yajl_object_loop(node:i:key:val);
  select key;
    when-is 'temperature';
      current.temperature = yajl_get_number(val);
    when-is 'weather_descriptions';
      descrip = yajl_object_find(node:'weather_descriptions');
      j = 0;
      dow yajl_array_loop(descrip:j:val);
        current.weather_descriptions(j) = yajl_get_string(val);
      enddo;
      current.num_weather_descriptions = (j-1);
    when-is 'wind_speed';
      current.wind_speed = yajl_get_number(val);
    when-is 'wind_degree';
      current.wind_degree = yajl_get_number(val);
    when-is 'wind_dir';
      current.wind_dir = yajl_get_string(val);
    when-is 'pressure';
      current.pressure = yajl_get_number(val);
    when-is 'precip';
      current.precip = yajl_get_number(val);
    when-is 'humidity';
      current.humidity = yajl_get_number(val);
    when-is 'cloudcover';
      current.cloudcover = yajl_get_number(val);
    when-is 'feelslike';
      current.feelslike = yajl_get_number(val);
    when-is 'uv_index';
      current.uv_index = yajl_get_number(val);
    when-is 'visibility';
      current.visibility = yajl_get_number(val);
  endsl;
enddo;

// Libera la memoria asignada al JSON al principio del proceso
yajl_tree_free(docNode);

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