--
-- PostgreSQL database dump
--

\restrict t8NksrNSvaoBeZaFdkffdUhS7wQCalicBgDeVGHxMgKnkqLm1GgY6A922VkC5w7

-- Dumped from database version 16.11
-- Dumped by pg_dump version 16.11

-- Started on 2026-03-30 20:18:15

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 10 (class 2615 OID 19979)
-- Name: pertanian; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA pertanian;


ALTER SCHEMA pertanian OWNER TO postgres;

--
-- TOC entry 8 (class 2615 OID 19811)
-- Name: topology; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA topology;


ALTER SCHEMA topology OWNER TO postgres;

--
-- TOC entry 6165 (class 0 OID 0)
-- Dependencies: 8
-- Name: SCHEMA topology; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA topology IS 'PostGIS Topology schema';


--
-- TOC entry 9 (class 2615 OID 19978)
-- Name: transportasi; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA transportasi;


ALTER SCHEMA transportasi OWNER TO postgres;

--
-- TOC entry 2 (class 3079 OID 18596)
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- TOC entry 6166 (class 0 OID 0)
-- Dependencies: 2
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';


--
-- TOC entry 3 (class 3079 OID 19812)
-- Name: postgis_topology; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis_topology WITH SCHEMA topology;


--
-- TOC entry 6167 (class 0 OID 0)
-- Dependencies: 3
-- Name: EXTENSION postgis_topology; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis_topology IS 'PostGIS topology spatial types and functions';


--
-- TOC entry 971 (class 1255 OID 20140)
-- Name: cari_kios_terdekat(double precision, double precision, integer); Type: FUNCTION; Schema: pertanian; Owner: postgres
--

CREATE FUNCTION pertanian.cari_kios_terdekat(p_lon double precision, p_lat double precision, p_limit integer DEFAULT 3) RETURNS TABLE(id integer, nama_kios character varying, jenis_pupuk text[], kuota_ton numeric, jarak_meter numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        k.id,
        k.nama_kios,
        k.jenis_pupuk,
        k.kuota_ton,
        ROUND(ST_Distance(k.geom::geography, ST_SetSRID(ST_Point(p_lon, p_lat), 4326)::geography)::numeric, 2)
    FROM pertanian.kios_pupuk k
    WHERE k.aktif = TRUE
    ORDER BY k.geom <-> ST_SetSRID(ST_Point(p_lon, p_lat), 4326)
    LIMIT p_limit;
END;
$$;


ALTER FUNCTION pertanian.cari_kios_terdekat(p_lon double precision, p_lat double precision, p_limit integer) OWNER TO postgres;

--
-- TOC entry 962 (class 1255 OID 20137)
-- Name: cari_halte_radius(double precision, double precision, integer); Type: FUNCTION; Schema: transportasi; Owner: postgres
--

CREATE FUNCTION transportasi.cari_halte_radius(p_lon double precision, p_lat double precision, p_radius integer DEFAULT 1000) RETURNS TABLE(id integer, nama character varying, jenis character varying, jarak_meter numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        h.id,
        h.nama,
        h.jenis,
        ROUND(ST_Distance(h.geom::geography, ST_SetSRID(ST_Point(p_lon, p_lat), 4326)::geography)::numeric, 2)
    FROM transportasi.halte h
    WHERE ST_DWithin(h.geom::geography, ST_SetSRID(ST_Point(p_lon, p_lat), 4326)::geography, p_radius)
      AND h.aktif = TRUE
    ORDER BY h.geom <-> ST_SetSRID(ST_Point(p_lon, p_lat), 4326);
END;
$$;


ALTER FUNCTION transportasi.cari_halte_radius(p_lon double precision, p_lat double precision, p_radius integer) OWNER TO postgres;

--
-- TOC entry 398 (class 1255 OID 20138)
-- Name: get_halte_geojson(character varying); Type: FUNCTION; Schema: transportasi; Owner: postgres
--

CREATE FUNCTION transportasi.get_halte_geojson(p_jenis character varying DEFAULT NULL::character varying) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN (
        SELECT jsonb_build_object(
            'type', 'FeatureCollection',
            'features', COALESCE(jsonb_agg(
                jsonb_build_object(
                    'type', 'Feature',
                    'geometry', ST_AsGeoJSON(geom)::jsonb,
                    'properties', jsonb_build_object(
                        'id', id,
                        'nama', nama,
                        'kode', kode,
                        'jenis', jenis,
                        'kapasitas', kapasitas
                    )
                )
            ), '[]'::jsonb)
        )
        FROM transportasi.halte
        WHERE aktif = TRUE
          AND (p_jenis IS NULL OR jenis = p_jenis)
    );
END;
$$;


ALTER FUNCTION transportasi.get_halte_geojson(p_jenis character varying) OWNER TO postgres;

--
-- TOC entry 690 (class 1255 OID 20139)
-- Name: statistik_wilayah(integer); Type: FUNCTION; Schema: transportasi; Owner: postgres
--

CREATE FUNCTION transportasi.statistik_wilayah(p_wilayah_id integer) RETURNS TABLE(nama_wilayah character varying, luas_km2 numeric, jumlah_halte bigint, jumlah_parkir bigint, jumlah_kecelakaan bigint, total_korban bigint)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        w.nama,
        w.luas_km2,
        (SELECT COUNT(*) FROM transportasi.halte h WHERE ST_Within(h.geom, w.geom) AND h.aktif = TRUE),
        (SELECT COUNT(*) FROM transportasi.parkir p WHERE ST_Within(p.geom, w.geom)),
        (SELECT COUNT(*) FROM transportasi.kecelakaan k WHERE ST_Within(k.geom, w.geom)),
        (SELECT COALESCE(SUM(k.jumlah_korban), 0) FROM transportasi.kecelakaan k WHERE ST_Within(k.geom, w.geom))
    FROM transportasi.wilayah w
    WHERE w.id = p_wilayah_id;
END;
$$;


ALTER FUNCTION transportasi.statistik_wilayah(p_wilayah_id integer) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 254 (class 1259 OID 20097)
-- Name: deteksi_objek; Type: TABLE; Schema: pertanian; Owner: postgres
--

CREATE TABLE pertanian.deteksi_objek (
    id integer NOT NULL,
    citra_sumber character varying(255),
    tanggal_deteksi timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    model_digunakan character varying(50),
    kelas_objek character varying(50),
    confidence numeric(5,4),
    geom public.geometry(Point,4326)
);


ALTER TABLE pertanian.deteksi_objek OWNER TO postgres;

--
-- TOC entry 253 (class 1259 OID 20096)
-- Name: deteksi_objek_id_seq; Type: SEQUENCE; Schema: pertanian; Owner: postgres
--

CREATE SEQUENCE pertanian.deteksi_objek_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE pertanian.deteksi_objek_id_seq OWNER TO postgres;

--
-- TOC entry 6168 (class 0 OID 0)
-- Dependencies: 253
-- Name: deteksi_objek_id_seq; Type: SEQUENCE OWNED BY; Schema: pertanian; Owner: postgres
--

ALTER SEQUENCE pertanian.deteksi_objek_id_seq OWNED BY pertanian.deteksi_objek.id;


--
-- TOC entry 250 (class 1259 OID 20076)
-- Name: hama_penyakit; Type: TABLE; Schema: pertanian; Owner: postgres
--

CREATE TABLE pertanian.hama_penyakit (
    id integer NOT NULL,
    tanggal_kejadian date NOT NULL,
    jenis character varying(50),
    nama_hama_penyakit character varying(100),
    tingkat_serangan character varying(20),
    luas_terdampak_ha numeric(10,2),
    tanaman_terdampak character varying(50),
    tindakan text,
    status character varying(20) DEFAULT 'aktif'::character varying,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    geom public.geometry(Point,4326)
);


ALTER TABLE pertanian.hama_penyakit OWNER TO postgres;

--
-- TOC entry 249 (class 1259 OID 20075)
-- Name: hama_penyakit_id_seq; Type: SEQUENCE; Schema: pertanian; Owner: postgres
--

CREATE SEQUENCE pertanian.hama_penyakit_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE pertanian.hama_penyakit_id_seq OWNER TO postgres;

--
-- TOC entry 6169 (class 0 OID 0)
-- Dependencies: 249
-- Name: hama_penyakit_id_seq; Type: SEQUENCE OWNED BY; Schema: pertanian; Owner: postgres
--

ALTER SEQUENCE pertanian.hama_penyakit_id_seq OWNED BY pertanian.hama_penyakit.id;


--
-- TOC entry 252 (class 1259 OID 20087)
-- Name: irigasi; Type: TABLE; Schema: pertanian; Owner: postgres
--

CREATE TABLE pertanian.irigasi (
    id integer NOT NULL,
    nama_saluran character varying(100),
    jenis character varying(50),
    panjang_km numeric(10,2),
    lebar_m numeric(5,2),
    kondisi character varying(50),
    tahun_bangun integer,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    geom public.geometry(LineString,4326)
);


ALTER TABLE pertanian.irigasi OWNER TO postgres;

--
-- TOC entry 251 (class 1259 OID 20086)
-- Name: irigasi_id_seq; Type: SEQUENCE; Schema: pertanian; Owner: postgres
--

CREATE SEQUENCE pertanian.irigasi_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE pertanian.irigasi_id_seq OWNER TO postgres;

--
-- TOC entry 6170 (class 0 OID 0)
-- Dependencies: 251
-- Name: irigasi_id_seq; Type: SEQUENCE OWNED BY; Schema: pertanian; Owner: postgres
--

ALTER SEQUENCE pertanian.irigasi_id_seq OWNED BY pertanian.irigasi.id;


--
-- TOC entry 248 (class 1259 OID 20066)
-- Name: kelompok_tani; Type: TABLE; Schema: pertanian; Owner: postgres
--

CREATE TABLE pertanian.kelompok_tani (
    id integer NOT NULL,
    nama_kelompok character varying(100) NOT NULL,
    ketua character varying(100),
    jumlah_anggota integer,
    desa character varying(100),
    kecamatan character varying(100),
    total_lahan_ha numeric(10,2),
    komoditas_utama character varying(50),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    geom public.geometry(Point,4326)
);


ALTER TABLE pertanian.kelompok_tani OWNER TO postgres;

--
-- TOC entry 247 (class 1259 OID 20065)
-- Name: kelompok_tani_id_seq; Type: SEQUENCE; Schema: pertanian; Owner: postgres
--

CREATE SEQUENCE pertanian.kelompok_tani_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE pertanian.kelompok_tani_id_seq OWNER TO postgres;

--
-- TOC entry 6171 (class 0 OID 0)
-- Dependencies: 247
-- Name: kelompok_tani_id_seq; Type: SEQUENCE OWNED BY; Schema: pertanian; Owner: postgres
--

ALTER SEQUENCE pertanian.kelompok_tani_id_seq OWNED BY pertanian.kelompok_tani.id;


--
-- TOC entry 246 (class 1259 OID 20054)
-- Name: kios_pupuk; Type: TABLE; Schema: pertanian; Owner: postgres
--

CREATE TABLE pertanian.kios_pupuk (
    id integer NOT NULL,
    nama_kios character varying(100) NOT NULL,
    pemilik character varying(100),
    no_izin character varying(50),
    alamat text,
    telepon character varying(20),
    jenis_pupuk text[],
    kuota_ton numeric(10,2),
    radius_layanan_km numeric(5,2) DEFAULT 5.0,
    aktif boolean DEFAULT true,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    geom public.geometry(Point,4326)
);


ALTER TABLE pertanian.kios_pupuk OWNER TO postgres;

--
-- TOC entry 245 (class 1259 OID 20053)
-- Name: kios_pupuk_id_seq; Type: SEQUENCE; Schema: pertanian; Owner: postgres
--

CREATE SEQUENCE pertanian.kios_pupuk_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE pertanian.kios_pupuk_id_seq OWNER TO postgres;

--
-- TOC entry 6172 (class 0 OID 0)
-- Dependencies: 245
-- Name: kios_pupuk_id_seq; Type: SEQUENCE OWNED BY; Schema: pertanian; Owner: postgres
--

ALTER SEQUENCE pertanian.kios_pupuk_id_seq OWNED BY pertanian.kios_pupuk.id;


--
-- TOC entry 244 (class 1259 OID 20042)
-- Name: lahan; Type: TABLE; Schema: pertanian; Owner: postgres
--

CREATE TABLE pertanian.lahan (
    id integer NOT NULL,
    kode_lahan character varying(20),
    nama_pemilik character varying(100),
    nik_pemilik character varying(20),
    jenis_tanaman character varying(50),
    luas_hektar numeric(10,2),
    status_kepemilikan character varying(50),
    tahun_tanam integer,
    produktivitas_ton_per_ha numeric(10,2),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    geom public.geometry(Polygon,4326)
);


ALTER TABLE pertanian.lahan OWNER TO postgres;

--
-- TOC entry 243 (class 1259 OID 20041)
-- Name: lahan_id_seq; Type: SEQUENCE; Schema: pertanian; Owner: postgres
--

CREATE SEQUENCE pertanian.lahan_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE pertanian.lahan_id_seq OWNER TO postgres;

--
-- TOC entry 6173 (class 0 OID 0)
-- Dependencies: 243
-- Name: lahan_id_seq; Type: SEQUENCE OWNED BY; Schema: pertanian; Owner: postgres
--

ALTER SEQUENCE pertanian.lahan_id_seq OWNED BY pertanian.lahan.id;


--
-- TOC entry 257 (class 1259 OID 20128)
-- Name: v_lahan_kios; Type: VIEW; Schema: pertanian; Owner: postgres
--

CREATE VIEW pertanian.v_lahan_kios AS
 SELECT l.id,
    l.kode_lahan,
    l.nama_pemilik,
    l.jenis_tanaman,
    l.luas_hektar,
    l.produktivitas_ton_per_ha,
    (l.luas_hektar * COALESCE(l.produktivitas_ton_per_ha, (0)::numeric)) AS estimasi_produksi_ton,
    kp.nama_kios AS kios_terdekat,
    round((public.st_distance((public.st_centroid(l.geom))::public.geography, (kp.geom)::public.geography))::numeric, 2) AS jarak_ke_kios_m
   FROM (pertanian.lahan l
     CROSS JOIN LATERAL ( SELECT kios_pupuk.nama_kios,
            kios_pupuk.geom
           FROM pertanian.kios_pupuk
          WHERE (kios_pupuk.aktif = true)
          ORDER BY (kios_pupuk.geom OPERATOR(public.<->) public.st_centroid(l.geom))
         LIMIT 1) kp);


ALTER VIEW pertanian.v_lahan_kios OWNER TO postgres;

--
-- TOC entry 258 (class 1259 OID 20133)
-- Name: v_statistik_hama; Type: VIEW; Schema: pertanian; Owner: postgres
--

CREATE VIEW pertanian.v_statistik_hama AS
 SELECT tanaman_terdampak,
    jenis,
    count(*) AS jumlah_kejadian,
    sum(luas_terdampak_ha) AS total_luas_terdampak_ha,
    count(*) FILTER (WHERE ((status)::text = 'aktif'::text)) AS masih_aktif,
    count(*) FILTER (WHERE ((tingkat_serangan)::text = 'berat'::text)) AS serangan_berat
   FROM pertanian.hama_penyakit
  GROUP BY tanaman_terdampak, jenis
  ORDER BY (count(*)) DESC;


ALTER VIEW pertanian.v_statistik_hama OWNER TO postgres;

--
-- TOC entry 260 (class 1259 OID 20145)
-- Name: v_zona_risiko_hama; Type: VIEW; Schema: pertanian; Owner: postgres
--

CREATE VIEW pertanian.v_zona_risiko_hama AS
 SELECT 1 AS id,
    public.st_union((public.st_buffer((geom)::public.geography, (1000)::double precision))::public.geometry) AS geom
   FROM pertanian.hama_penyakit
  WHERE ((status)::text = 'aktif'::text);


ALTER VIEW pertanian.v_zona_risiko_hama OWNER TO postgres;

--
-- TOC entry 226 (class 1259 OID 19673)
-- Name: fasilitas_publik; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.fasilitas_publik (
    id integer NOT NULL,
    nama character varying(100),
    jenis character varying(50),
    alamat text,
    geom public.geometry(Point,4326)
);


ALTER TABLE public.fasilitas_publik OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 19672)
-- Name: fasilitas_publik_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.fasilitas_publik_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.fasilitas_publik_id_seq OWNER TO postgres;

--
-- TOC entry 6174 (class 0 OID 0)
-- Dependencies: 225
-- Name: fasilitas_publik_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.fasilitas_publik_id_seq OWNED BY public.fasilitas_publik.id;


--
-- TOC entry 234 (class 1259 OID 19981)
-- Name: halte; Type: TABLE; Schema: transportasi; Owner: postgres
--

CREATE TABLE transportasi.halte (
    id integer NOT NULL,
    nama character varying(100) NOT NULL,
    kode character varying(20),
    jenis character varying(50),
    alamat text,
    kapasitas integer,
    fasilitas text[],
    jam_operasi_mulai time without time zone,
    jam_operasi_selesai time without time zone,
    aktif boolean DEFAULT true,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    geom public.geometry(Point,4326)
);


ALTER TABLE transportasi.halte OWNER TO postgres;

--
-- TOC entry 233 (class 1259 OID 19980)
-- Name: halte_id_seq; Type: SEQUENCE; Schema: transportasi; Owner: postgres
--

CREATE SEQUENCE transportasi.halte_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE transportasi.halte_id_seq OWNER TO postgres;

--
-- TOC entry 6175 (class 0 OID 0)
-- Dependencies: 233
-- Name: halte_id_seq; Type: SEQUENCE OWNED BY; Schema: transportasi; Owner: postgres
--

ALTER SEQUENCE transportasi.halte_id_seq OWNED BY transportasi.halte.id;


--
-- TOC entry 240 (class 1259 OID 20020)
-- Name: kecelakaan; Type: TABLE; Schema: transportasi; Owner: postgres
--

CREATE TABLE transportasi.kecelakaan (
    id integer NOT NULL,
    tanggal date NOT NULL,
    waktu time without time zone,
    jenis_kecelakaan character varying(50),
    jumlah_korban integer DEFAULT 0,
    jumlah_kendaraan integer DEFAULT 1,
    penyebab text,
    kondisi_jalan character varying(50),
    kondisi_cuaca character varying(50),
    keterangan text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    geom public.geometry(Point,4326)
);


ALTER TABLE transportasi.kecelakaan OWNER TO postgres;

--
-- TOC entry 239 (class 1259 OID 20019)
-- Name: kecelakaan_id_seq; Type: SEQUENCE; Schema: transportasi; Owner: postgres
--

CREATE SEQUENCE transportasi.kecelakaan_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE transportasi.kecelakaan_id_seq OWNER TO postgres;

--
-- TOC entry 6176 (class 0 OID 0)
-- Dependencies: 239
-- Name: kecelakaan_id_seq; Type: SEQUENCE OWNED BY; Schema: transportasi; Owner: postgres
--

ALTER SEQUENCE transportasi.kecelakaan_id_seq OWNED BY transportasi.kecelakaan.id;


--
-- TOC entry 242 (class 1259 OID 20032)
-- Name: parkir; Type: TABLE; Schema: transportasi; Owner: postgres
--

CREATE TABLE transportasi.parkir (
    id integer NOT NULL,
    nama character varying(100) NOT NULL,
    jenis character varying(50),
    kapasitas integer,
    tarif_per_jam integer,
    jam_buka time without time zone,
    jam_tutup time without time zone,
    pengelola character varying(100),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    geom public.geometry(Point,4326)
);


ALTER TABLE transportasi.parkir OWNER TO postgres;

--
-- TOC entry 241 (class 1259 OID 20031)
-- Name: parkir_id_seq; Type: SEQUENCE; Schema: transportasi; Owner: postgres
--

CREATE SEQUENCE transportasi.parkir_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE transportasi.parkir_id_seq OWNER TO postgres;

--
-- TOC entry 6177 (class 0 OID 0)
-- Dependencies: 241
-- Name: parkir_id_seq; Type: SEQUENCE OWNED BY; Schema: transportasi; Owner: postgres
--

ALTER SEQUENCE transportasi.parkir_id_seq OWNED BY transportasi.parkir.id;


--
-- TOC entry 236 (class 1259 OID 19995)
-- Name: rute; Type: TABLE; Schema: transportasi; Owner: postgres
--

CREATE TABLE transportasi.rute (
    id integer NOT NULL,
    kode_rute character varying(20) NOT NULL,
    nama_rute character varying(100) NOT NULL,
    jenis character varying(50),
    warna character varying(20),
    panjang_km numeric(10,2),
    estimasi_waktu_menit integer,
    tarif integer,
    aktif boolean DEFAULT true,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    geom public.geometry(LineString,4326)
);


ALTER TABLE transportasi.rute OWNER TO postgres;

--
-- TOC entry 235 (class 1259 OID 19994)
-- Name: rute_id_seq; Type: SEQUENCE; Schema: transportasi; Owner: postgres
--

CREATE SEQUENCE transportasi.rute_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE transportasi.rute_id_seq OWNER TO postgres;

--
-- TOC entry 6178 (class 0 OID 0)
-- Dependencies: 235
-- Name: rute_id_seq; Type: SEQUENCE OWNED BY; Schema: transportasi; Owner: postgres
--

ALTER SEQUENCE transportasi.rute_id_seq OWNED BY transportasi.rute.id;


--
-- TOC entry 238 (class 1259 OID 20008)
-- Name: wilayah; Type: TABLE; Schema: transportasi; Owner: postgres
--

CREATE TABLE transportasi.wilayah (
    id integer NOT NULL,
    kode_wilayah character varying(20),
    nama character varying(100) NOT NULL,
    tipe character varying(50),
    populasi integer,
    luas_km2 numeric(10,2),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    geom public.geometry(Polygon,4326)
);


ALTER TABLE transportasi.wilayah OWNER TO postgres;

--
-- TOC entry 261 (class 1259 OID 20149)
-- Name: v_blank_spot_transportasi; Type: VIEW; Schema: transportasi; Owner: postgres
--

CREATE VIEW transportasi.v_blank_spot_transportasi AS
 SELECT id,
    nama,
    public.st_difference(geom, ( SELECT public.st_union((public.st_buffer((halte.geom)::public.geography, (500)::double precision))::public.geometry) AS st_union
           FROM transportasi.halte)) AS geom
   FROM transportasi.wilayah w;


ALTER VIEW transportasi.v_blank_spot_transportasi OWNER TO postgres;

--
-- TOC entry 262 (class 1259 OID 20153)
-- Name: v_centroid_wilayah; Type: VIEW; Schema: transportasi; Owner: postgres
--

CREATE VIEW transportasi.v_centroid_wilayah AS
 SELECT id,
    nama,
    public.st_centroid(geom) AS geom
   FROM transportasi.wilayah;


ALTER VIEW transportasi.v_centroid_wilayah OWNER TO postgres;

--
-- TOC entry 255 (class 1259 OID 20118)
-- Name: v_halte_wilayah; Type: VIEW; Schema: transportasi; Owner: postgres
--

CREATE VIEW transportasi.v_halte_wilayah AS
 SELECT h.id,
    h.nama,
    h.kode,
    h.jenis,
    h.kapasitas,
    h.fasilitas,
    w.nama AS wilayah,
    public.st_x(h.geom) AS longitude,
    public.st_y(h.geom) AS latitude,
    h.geom
   FROM (transportasi.halte h
     LEFT JOIN transportasi.wilayah w ON (public.st_within(h.geom, w.geom)))
  WHERE (h.aktif = true);


ALTER VIEW transportasi.v_halte_wilayah OWNER TO postgres;

--
-- TOC entry 256 (class 1259 OID 20123)
-- Name: v_statistik_kecelakaan; Type: VIEW; Schema: transportasi; Owner: postgres
--

CREATE VIEW transportasi.v_statistik_kecelakaan AS
 SELECT w.nama AS wilayah,
    w.populasi,
    count(k.id) AS jumlah_kejadian,
    sum(COALESCE(k.jumlah_korban, 0)) AS total_korban,
    count(*) FILTER (WHERE ((k.jenis_kecelakaan)::text = 'fatal'::text)) AS kejadian_fatal,
    count(*) FILTER (WHERE ((k.jenis_kecelakaan)::text = 'berat'::text)) AS kejadian_berat,
    count(*) FILTER (WHERE ((k.jenis_kecelakaan)::text = 'sedang'::text)) AS kejadian_sedang,
    count(*) FILTER (WHERE ((k.jenis_kecelakaan)::text = 'ringan'::text)) AS kejadian_ringan
   FROM (transportasi.wilayah w
     LEFT JOIN transportasi.kecelakaan k ON (public.st_within(k.geom, w.geom)))
  GROUP BY w.id, w.nama, w.populasi;


ALTER VIEW transportasi.v_statistik_kecelakaan OWNER TO postgres;

--
-- TOC entry 259 (class 1259 OID 20141)
-- Name: v_zona_layanan_transportasi; Type: VIEW; Schema: transportasi; Owner: postgres
--

CREATE VIEW transportasi.v_zona_layanan_transportasi AS
 SELECT 1 AS id,
    public.st_union((public.st_buffer((geom)::public.geography, (500)::double precision))::public.geometry) AS geom
   FROM transportasi.halte;


ALTER VIEW transportasi.v_zona_layanan_transportasi OWNER TO postgres;

--
-- TOC entry 237 (class 1259 OID 20007)
-- Name: wilayah_id_seq; Type: SEQUENCE; Schema: transportasi; Owner: postgres
--

CREATE SEQUENCE transportasi.wilayah_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE transportasi.wilayah_id_seq OWNER TO postgres;

--
-- TOC entry 6179 (class 0 OID 0)
-- Dependencies: 237
-- Name: wilayah_id_seq; Type: SEQUENCE OWNED BY; Schema: transportasi; Owner: postgres
--

ALTER SEQUENCE transportasi.wilayah_id_seq OWNED BY transportasi.wilayah.id;


--
-- TOC entry 5924 (class 2604 OID 20100)
-- Name: deteksi_objek id; Type: DEFAULT; Schema: pertanian; Owner: postgres
--

ALTER TABLE ONLY pertanian.deteksi_objek ALTER COLUMN id SET DEFAULT nextval('pertanian.deteksi_objek_id_seq'::regclass);


--
-- TOC entry 5919 (class 2604 OID 20079)
-- Name: hama_penyakit id; Type: DEFAULT; Schema: pertanian; Owner: postgres
--

ALTER TABLE ONLY pertanian.hama_penyakit ALTER COLUMN id SET DEFAULT nextval('pertanian.hama_penyakit_id_seq'::regclass);


--
-- TOC entry 5922 (class 2604 OID 20090)
-- Name: irigasi id; Type: DEFAULT; Schema: pertanian; Owner: postgres
--

ALTER TABLE ONLY pertanian.irigasi ALTER COLUMN id SET DEFAULT nextval('pertanian.irigasi_id_seq'::regclass);


--
-- TOC entry 5917 (class 2604 OID 20069)
-- Name: kelompok_tani id; Type: DEFAULT; Schema: pertanian; Owner: postgres
--

ALTER TABLE ONLY pertanian.kelompok_tani ALTER COLUMN id SET DEFAULT nextval('pertanian.kelompok_tani_id_seq'::regclass);


--
-- TOC entry 5913 (class 2604 OID 20057)
-- Name: kios_pupuk id; Type: DEFAULT; Schema: pertanian; Owner: postgres
--

ALTER TABLE ONLY pertanian.kios_pupuk ALTER COLUMN id SET DEFAULT nextval('pertanian.kios_pupuk_id_seq'::regclass);


--
-- TOC entry 5911 (class 2604 OID 20045)
-- Name: lahan id; Type: DEFAULT; Schema: pertanian; Owner: postgres
--

ALTER TABLE ONLY pertanian.lahan ALTER COLUMN id SET DEFAULT nextval('pertanian.lahan_id_seq'::regclass);


--
-- TOC entry 5893 (class 2604 OID 19676)
-- Name: fasilitas_publik id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fasilitas_publik ALTER COLUMN id SET DEFAULT nextval('public.fasilitas_publik_id_seq'::regclass);


--
-- TOC entry 5897 (class 2604 OID 19984)
-- Name: halte id; Type: DEFAULT; Schema: transportasi; Owner: postgres
--

ALTER TABLE ONLY transportasi.halte ALTER COLUMN id SET DEFAULT nextval('transportasi.halte_id_seq'::regclass);


--
-- TOC entry 5905 (class 2604 OID 20023)
-- Name: kecelakaan id; Type: DEFAULT; Schema: transportasi; Owner: postgres
--

ALTER TABLE ONLY transportasi.kecelakaan ALTER COLUMN id SET DEFAULT nextval('transportasi.kecelakaan_id_seq'::regclass);


--
-- TOC entry 5909 (class 2604 OID 20035)
-- Name: parkir id; Type: DEFAULT; Schema: transportasi; Owner: postgres
--

ALTER TABLE ONLY transportasi.parkir ALTER COLUMN id SET DEFAULT nextval('transportasi.parkir_id_seq'::regclass);


--
-- TOC entry 5900 (class 2604 OID 19998)
-- Name: rute id; Type: DEFAULT; Schema: transportasi; Owner: postgres
--

ALTER TABLE ONLY transportasi.rute ALTER COLUMN id SET DEFAULT nextval('transportasi.rute_id_seq'::regclass);


--
-- TOC entry 5903 (class 2604 OID 20011)
-- Name: wilayah id; Type: DEFAULT; Schema: transportasi; Owner: postgres
--

ALTER TABLE ONLY transportasi.wilayah ALTER COLUMN id SET DEFAULT nextval('transportasi.wilayah_id_seq'::regclass);


--
-- TOC entry 6159 (class 0 OID 20097)
-- Dependencies: 254
-- Data for Name: deteksi_objek; Type: TABLE DATA; Schema: pertanian; Owner: postgres
--

COPY pertanian.deteksi_objek (id, citra_sumber, tanggal_deteksi, model_digunakan, kelas_objek, confidence, geom) FROM stdin;
\.


--
-- TOC entry 6155 (class 0 OID 20076)
-- Dependencies: 250
-- Data for Name: hama_penyakit; Type: TABLE DATA; Schema: pertanian; Owner: postgres
--

COPY pertanian.hama_penyakit (id, tanggal_kejadian, jenis, nama_hama_penyakit, tingkat_serangan, luas_terdampak_ha, tanaman_terdampak, tindakan, status, created_at, geom) FROM stdin;
1	2024-01-10	hama	penggerek_buah_kopi	sedang	5.50	kopi_robusta	Penyemprotan pestisida	terkendali	2026-03-30 18:43:10.516561	0101000020E6100000EC51B81E85035A40F6285C8FC27514C0
2	2024-01-25	penyakit	karat_daun	ringan	2.00	kopi_arabika	Aplikasi fungisida	selesai	2026-03-30 18:43:10.516561	0101000020E61000003D0AD7A370055A4000000000008014C0
3	2024-02-08	hama	wereng	berat	15.00	padi	Penyemprotan massal	aktif	2026-03-30 18:43:10.516561	0101000020E6100000713D0AD7A3085A40D7A3703D0A5714C0
4	2024-02-20	hama	ulat_grayak	sedang	8.00	jagung	Pengendalian hayati	terkendali	2026-03-30 18:43:10.516561	0101000020E61000005C8FC2F528045A4014AE47E17A9414C0
5	2024-03-05	penyakit	busuk_akar	ringan	3.00	kopi_robusta	Drainase dan fungisida	selesai	2026-03-30 18:43:10.516561	0101000020E61000007B14AE47E1025A400AD7A3703D8A14C0
6	2024-03-18	hama	kutu_putih	sedang	6.50	sawit	Penyemprotan sistemik	terkendali	2026-03-30 18:43:10.516561	0101000020E6100000C3F5285C8F0A5A40C3F5285C8F4214C0
7	2024-04-02	penyakit	blast	berat	12.00	padi	Aplikasi fungisida intensif	aktif	2026-03-30 18:43:10.516561	0101000020E6100000E17A14AE47095A40EC51B81E856B14C0
8	2024-04-15	hama	tikus	sedang	4.50	padi	Gropyokan dan umpan beracun	terkendali	2026-03-30 18:43:10.516561	0101000020E610000052B81E85EB095A40CDCCCCCCCC4C14C0
9	2024-05-01	penyakit	antraknosa	ringan	2.50	kopi_arabika	Pemangkasan dan fungisida	selesai	2026-03-30 18:43:10.516561	0101000020E6100000AE47E17A14065A40F6285C8FC27514C0
10	2024-05-12	hama	nematoda	sedang	7.00	kopi_robusta	Aplikasi nematisida	aktif	2026-03-30 18:43:10.516561	0101000020E61000009A99999999015A401F85EB51B89E14C0
11	2024-06-01	hama	penggerek_batang	berat	10.00	padi	Penyemprotan intensif	aktif	2026-03-30 18:43:10.516561	0101000020E61000000000000000085A40E17A14AE476114C0
12	2024-06-15	penyakit	jamur_upas	sedang	4.00	karet	Aplikasi fungisida	terkendali	2026-03-30 18:43:10.516561	0101000020E61000008FC2F5285C075A40295C8FC2F5A814C0
13	2024-07-01	hama	kutu_hijau	ringan	3.50	kopi_robusta	Predator alami	selesai	2026-03-30 18:43:10.516561	0101000020E6100000EC51B81E85035A40EC51B81E856B14C0
14	2024-07-10	penyakit	vsd	berat	8.50	kakao	Pemangkasan sanitasi	aktif	2026-03-30 18:43:10.516561	0101000020E61000008FC2F5285C075A400AD7A3703D8A14C0
15	2024-07-20	hama	lalat_buah	sedang	5.00	kopi_arabika	Perangkap feromon	terkendali	2026-03-30 18:43:10.516561	0101000020E6100000CDCCCCCCCC045A40E17A14AE476114C0
\.


--
-- TOC entry 6157 (class 0 OID 20087)
-- Dependencies: 252
-- Data for Name: irigasi; Type: TABLE DATA; Schema: pertanian; Owner: postgres
--

COPY pertanian.irigasi (id, nama_saluran, jenis, panjang_km, lebar_m, kondisi, tahun_bangun, created_at, geom) FROM stdin;
1	Saluran Primer Way Tenong	primer	12.50	4.00	baik	2005	2026-03-30 18:43:19.977435	0102000020E610000004000000E17A14AE47015A4052B81E85EB5114C085EB51B81E055A4066666666666614C0295C8FC2F5085A405C8FC2F5285C14C0EC51B81E850B5A4048E17A14AE4714C0
2	Saluran Sekunder Sukanegara	sekunder	5.20	2.00	sedang	2010	2026-03-30 18:43:19.977435	0102000020E61000000300000085EB51B81E055A4066666666666614C0A4703D0AD7035A407B14AE47E17A14C03333333333035A408FC2F5285C8F14C0
3	Saluran Tersier Blok A	tersier	1.50	0.80	baik	2018	2026-03-30 18:43:19.977435	0102000020E6100000030000003333333333035A4066666666666614C0A4703D0AD7035A40713D0AD7A37014C014AE47E17A045A40713D0AD7A37014C0
4	Saluran Sekunder Sekincau	sekunder	6.80	2.50	rusak	2008	2026-03-30 18:43:19.977435	0102000020E610000003000000295C8FC2F5085A405C8FC2F5285C14C09A99999999095A4048E17A14AE4714C00AD7A3703D0A5A403D0AD7A3703D14C0
5	Saluran Primer Balik Bukit	primer	8.50	3.50	baik	2012	2026-03-30 18:43:19.977435	0102000020E6100000040000006666666666065A4066666666666614C048E17A14AE075A407B14AE47E17A14C0295C8FC2F5085A408FC2F5285C8F14C09A99999999095A40A4703D0AD7A314C0
6	Saluran Tersier Blok B	tersier	2.00	1.00	sedang	2015	2026-03-30 18:43:19.977435	0102000020E61000000300000048E17A14AE075A4052B81E85EB5114C0B81E85EB51085A405C8FC2F5285C14C0295C8FC2F5085A405C8FC2F5285C14C0
7	Saluran Sekunder Fajar Bulan	sekunder	4.50	2.00	baik	2016	2026-03-30 18:43:19.977435	0102000020E61000000300000014AE47E17A045A4066666666666614C085EB51B81E055A40713D0AD7A37014C0F6285C8FC2055A4085EB51B81E8514C0
\.


--
-- TOC entry 6153 (class 0 OID 20066)
-- Dependencies: 248
-- Data for Name: kelompok_tani; Type: TABLE DATA; Schema: pertanian; Owner: postgres
--

COPY pertanian.kelompok_tani (id, nama_kelompok, ketua, jumlah_anggota, desa, kecamatan, total_lahan_ha, komoditas_utama, created_at, geom) FROM stdin;
1	Poktan Maju Bersama	Suparman	45	Sukanegara	Way Tenong	125.50	kopi_robusta	2026-03-30 18:42:57.944478	0101000020E6100000A4703D0AD7035A40713D0AD7A37014C0
2	Poktan Sumber Rejeki	Mardianto	38	Fajar Bulan	Way Tenong	95.00	kopi_arabika	2026-03-30 18:42:57.944478	0101000020E6100000F6285C8FC2055A4085EB51B81E8514C0
3	Poktan Tani Jaya	Suroto	52	Sekincau	Sekincau	145.00	padi	2026-03-30 18:42:57.944478	0101000020E6100000295C8FC2F5085A4052B81E85EB5114C0
4	Poktan Mekar Sari	Sutrisno	35	Liwa	Balik Bukit	85.00	sayuran	2026-03-30 18:42:57.944478	0101000020E6100000D7A3703D0A075A4066666666666614C0
5	Poktan Harum Manis	Karman	40	Pekon Balak	Batu Brak	110.00	kopi_robusta	2026-03-30 18:42:57.944478	0101000020E6100000C3F5285C8F025A408FC2F5285C8F14C0
6	Poktan Subur Makmur	Wijaya	48	Gunung Terang	Way Tenong	135.00	kopi_robusta	2026-03-30 18:42:57.944478	0101000020E610000014AE47E17A045A407B14AE47E17A14C0
7	Poktan Sinar Tani	Rohman	32	Padang Cahya	Sekincau	78.00	padi	2026-03-30 18:42:57.944478	0101000020E61000000AD7A3703D0A5A405C8FC2F5285C14C0
8	Poktan Karya Mandiri	Slamet	42	Way Mengaku	Balik Bukit	105.00	jagung	2026-03-30 18:42:57.944478	0101000020E610000048E17A14AE075A409A999999999914C0
9	Poktan Maju Bersama	Suparman	45	Sukanegara	Way Tenong	125.50	kopi_robusta	2026-03-30 18:42:59.689119	0101000020E6100000A4703D0AD7035A40713D0AD7A37014C0
10	Poktan Sumber Rejeki	Mardianto	38	Fajar Bulan	Way Tenong	95.00	kopi_arabika	2026-03-30 18:42:59.689119	0101000020E6100000F6285C8FC2055A4085EB51B81E8514C0
11	Poktan Tani Jaya	Suroto	52	Sekincau	Sekincau	145.00	padi	2026-03-30 18:42:59.689119	0101000020E6100000295C8FC2F5085A4052B81E85EB5114C0
12	Poktan Mekar Sari	Sutrisno	35	Liwa	Balik Bukit	85.00	sayuran	2026-03-30 18:42:59.689119	0101000020E6100000D7A3703D0A075A4066666666666614C0
13	Poktan Harum Manis	Karman	40	Pekon Balak	Batu Brak	110.00	kopi_robusta	2026-03-30 18:42:59.689119	0101000020E6100000C3F5285C8F025A408FC2F5285C8F14C0
14	Poktan Subur Makmur	Wijaya	48	Gunung Terang	Way Tenong	135.00	kopi_robusta	2026-03-30 18:42:59.689119	0101000020E610000014AE47E17A045A407B14AE47E17A14C0
15	Poktan Sinar Tani	Rohman	32	Padang Cahya	Sekincau	78.00	padi	2026-03-30 18:42:59.689119	0101000020E61000000AD7A3703D0A5A405C8FC2F5285C14C0
16	Poktan Karya Mandiri	Slamet	42	Way Mengaku	Balik Bukit	105.00	jagung	2026-03-30 18:42:59.689119	0101000020E610000048E17A14AE075A409A999999999914C0
\.


--
-- TOC entry 6151 (class 0 OID 20054)
-- Dependencies: 246
-- Data for Name: kios_pupuk; Type: TABLE DATA; Schema: pertanian; Owner: postgres
--

COPY pertanian.kios_pupuk (id, nama_kios, pemilik, no_izin, alamat, telepon, jenis_pupuk, kuota_ton, radius_layanan_km, aktif, created_at, geom) FROM stdin;
1	Kios Tani Makmur	Agus Riyanto	IZN-2023-001	Jl. Lintas Sumatera KM 5	\N	{urea,npk,za}	50.00	8.00	t	2026-03-30 18:42:50.335744	0101000020E610000085EB51B81E055A407B14AE47E17A14C0
2	Kios Berkah Tani	Sri Mulyani	IZN-2023-002	Desa Sukanegara	\N	{urea,npk,organik}	35.00	5.00	t	2026-03-30 18:42:50.335744	0101000020E610000048E17A14AE075A405C8FC2F5285C14C0
3	Kios Subur Jaya	Bambang Sutrisno	IZN-2023-003	Kec. Way Tenong	\N	{urea,za,kcl}	45.00	6.00	t	2026-03-30 18:42:50.335744	0101000020E61000003333333333035A409A999999999914C0
4	Kios Mitra Petani	Dewi Sartika	IZN-2023-004	Pasar Liwa	\N	{urea,npk,organik,za}	60.00	10.00	t	2026-03-30 18:42:50.335744	0101000020E61000006666666666065A40713D0AD7A37014C0
5	Kios Harapan Tani	Hasan Basri	IZN-2023-005	Desa Sekincau	\N	{urea,npk}	30.00	5.00	t	2026-03-30 18:42:50.335744	0101000020E61000009A99999999095A403D0AD7A3703D14C0
6	Kios Sejahtera	Surya Darma	IZN-2023-006	Desa Fajar Bulan	\N	{urea,npk,sp36}	40.00	7.00	t	2026-03-30 18:42:50.335744	0101000020E610000014AE47E17A045A4066666666666614C0
7	Kios Mandiri Tani	Rina Wati	IZN-2023-007	Kec. Balik Bukit	\N	{urea,npk,organik}	55.00	8.00	t	2026-03-30 18:42:50.335744	0101000020E6100000B81E85EB51085A408FC2F5285C8F14C0
8	Kios Lestari	Dodi Pratama	IZN-2023-008	Desa Pekon Balak	\N	{urea,za,npk}	45.00	6.00	t	2026-03-30 18:42:50.335744	0101000020E6100000C3F5285C8F025A4085EB51B81E8514C0
\.


--
-- TOC entry 6149 (class 0 OID 20042)
-- Dependencies: 244
-- Data for Name: lahan; Type: TABLE DATA; Schema: pertanian; Owner: postgres
--

COPY pertanian.lahan (id, kode_lahan, nama_pemilik, nik_pemilik, jenis_tanaman, luas_hektar, status_kepemilikan, tahun_tanam, produktivitas_ton_per_ha, created_at, geom) FROM stdin;
1	LHN-001	Ahmad Suryadi	\N	kopi_robusta	2.50	milik	2018	1.20	2026-03-30 18:42:40.440419	0103000020E610000001000000050000003333333333035A4066666666666614C014AE47E17A045A4066666666666614C014AE47E17A045A407B14AE47E17A14C03333333333035A407B14AE47E17A14C03333333333035A4066666666666614C0
2	LHN-002	Budi Santoso	\N	kopi_arabika	3.00	milik	2015	0.80	2026-03-30 18:42:40.440419	0103000020E6100000010000000500000085EB51B81E055A40713D0AD7A37014C06666666666065A40713D0AD7A37014C06666666666065A4085EB51B81E8514C085EB51B81E055A4085EB51B81E8514C085EB51B81E055A40713D0AD7A37014C0
3	LHN-003	Citra Dewi	\N	padi	1.50	sewa	2023	5.50	2026-03-30 18:42:40.440419	0103000020E6100000010000000500000048E17A14AE075A4052B81E85EB5114C0295C8FC2F5085A4052B81E85EB5114C0295C8FC2F5085A4066666666666614C048E17A14AE075A4066666666666614C048E17A14AE075A4052B81E85EB5114C0
4	LHN-004	Darmawan	\N	jagung	2.00	garapan	2023	7.00	2026-03-30 18:42:40.440419	0103000020E61000000100000005000000A4703D0AD7035A408FC2F5285C8F14C085EB51B81E055A408FC2F5285C8F14C085EB51B81E055A40A4703D0AD7A314C0A4703D0AD7035A40A4703D0AD7A314C0A4703D0AD7035A408FC2F5285C8F14C0
5	LHN-005	Eko Prasetyo	\N	kopi_robusta	4.00	milik	2016	1.50	2026-03-30 18:42:40.440419	0103000020E6100000010000000500000052B81E85EB015A407B14AE47E17A14C0A4703D0AD7035A407B14AE47E17A14C0A4703D0AD7035A409A999999999914C052B81E85EB015A409A999999999914C052B81E85EB015A407B14AE47E17A14C0
6	LHN-006	Fitri Handayani	\N	sawit	5.00	milik	2012	3.50	2026-03-30 18:42:40.440419	0103000020E610000001000000050000009A99999999095A4033333333333314C0EC51B81E850B5A4033333333333314C0EC51B81E850B5A4052B81E85EB5114C09A99999999095A4052B81E85EB5114C09A99999999095A4033333333333314C0
7	LHN-007	Gunawan	\N	karet	3.50	milik	2010	1.80	2026-03-30 18:42:40.440419	0103000020E610000001000000050000006666666666065A409A999999999914C0B81E85EB51085A409A999999999914C0B81E85EB51085A40B81E85EB51B814C06666666666065A40B81E85EB51B814C06666666666065A409A999999999914C0
8	LHN-008	Hendra Wijaya	\N	padi	2.00	milik	2023	6.00	2026-03-30 18:42:40.440419	0103000020E61000000100000005000000295C8FC2F5085A4066666666666614C00AD7A3703D0A5A4066666666666614C00AD7A3703D0A5A407B14AE47E17A14C0295C8FC2F5085A407B14AE47E17A14C0295C8FC2F5085A4066666666666614C0
9	LHN-009	Indah Permata	\N	kopi_arabika	1.80	milik	2017	0.90	2026-03-30 18:42:40.440419	0103000020E61000000100000005000000C3F5285C8F025A4052B81E85EB5114C0A4703D0AD7035A4052B81E85EB5114C0A4703D0AD7035A4066666666666614C0C3F5285C8F025A4066666666666614C0C3F5285C8F025A4052B81E85EB5114C0
10	LHN-010	Joko Susilo	\N	jagung	2.50	sewa	2023	6.50	2026-03-30 18:42:40.440419	0103000020E61000000100000005000000F6285C8FC2055A403D0AD7A3703D14C0D7A3703D0A075A403D0AD7A3703D14C0D7A3703D0A075A4052B81E85EB5114C0F6285C8FC2055A4052B81E85EB5114C0F6285C8FC2055A403D0AD7A3703D14C0
11	LHN-011	Kartini	\N	kopi_robusta	3.20	milik	2014	1.30	2026-03-30 18:42:40.440419	0103000020E61000000100000005000000E17A14AE47015A408FC2F5285C8F14C03333333333035A408FC2F5285C8F14C03333333333035A40AE47E17A14AE14C0E17A14AE47015A40AE47E17A14AE14C0E17A14AE47015A408FC2F5285C8F14C0
12	LHN-012	Lukman Hakim	\N	padi	1.00	garapan	2023	5.00	2026-03-30 18:42:40.440419	0103000020E610000001000000050000000AD7A3703D0A5A4048E17A14AE4714C07B14AE47E10A5A4048E17A14AE4714C07B14AE47E10A5A4052B81E85EB5114C00AD7A3703D0A5A4052B81E85EB5114C00AD7A3703D0A5A4048E17A14AE4714C0
13	LHN-013	Mardiyah	\N	kopi_robusta	2.80	milik	2019	1.10	2026-03-30 18:42:40.440419	0103000020E6100000010000000500000014AE47E17A045A405C8FC2F5285C14C0F6285C8FC2055A405C8FC2F5285C14C0F6285C8FC2055A40713D0AD7A37014C014AE47E17A045A40713D0AD7A37014C014AE47E17A045A405C8FC2F5285C14C0
14	LHN-014	Nugroho	\N	kakao	2.20	milik	2016	1.00	2026-03-30 18:42:40.440419	0103000020E61000000100000005000000D7A3703D0A075A407B14AE47E17A14C0B81E85EB51085A407B14AE47E17A14C0B81E85EB51085A408FC2F5285C8F14C0D7A3703D0A075A408FC2F5285C8F14C0D7A3703D0A075A407B14AE47E17A14C0
15	LHN-015	Oktavia	\N	lada	1.50	milik	2018	0.60	2026-03-30 18:42:40.440419	0103000020E610000001000000050000003333333333035A40A4703D0AD7A314C014AE47E17A045A40A4703D0AD7A314C014AE47E17A045A40B81E85EB51B814C03333333333035A40B81E85EB51B814C03333333333035A40A4703D0AD7A314C0
\.


--
-- TOC entry 6137 (class 0 OID 19673)
-- Dependencies: 226
-- Data for Name: fasilitas_publik; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.fasilitas_publik (id, nama, jenis, alamat, geom) FROM stdin;
\.


--
-- TOC entry 5889 (class 0 OID 18914)
-- Dependencies: 221
-- Data for Name: spatial_ref_sys; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.spatial_ref_sys (srid, auth_name, auth_srid, srtext, proj4text) FROM stdin;
\.


--
-- TOC entry 5891 (class 0 OID 19814)
-- Dependencies: 228
-- Data for Name: topology; Type: TABLE DATA; Schema: topology; Owner: postgres
--

COPY topology.topology (id, name, srid, "precision", hasz) FROM stdin;
\.


--
-- TOC entry 5892 (class 0 OID 19826)
-- Dependencies: 229
-- Data for Name: layer; Type: TABLE DATA; Schema: topology; Owner: postgres
--

COPY topology.layer (topology_id, layer_id, schema_name, table_name, feature_column, feature_type, level, child_id) FROM stdin;
\.


--
-- TOC entry 6139 (class 0 OID 19981)
-- Dependencies: 234
-- Data for Name: halte; Type: TABLE DATA; Schema: transportasi; Owner: postgres
--

COPY transportasi.halte (id, nama, kode, jenis, alamat, kapasitas, fasilitas, jam_operasi_mulai, jam_operasi_selesai, aktif, created_at, geom) FROM stdin;
1	Halte Tanjung Karang	HLT-001	brt	Jl. Raden Intan	50	{kursi_tunggu,atap,papan_info,cctv}	\N	\N	t	2026-03-30 18:41:48.677268	0101000020E6100000A2B437F8C2505A400F9C33A2B4B715C0
2	Halte Rajabasa	HLT-002	brt	Jl. ZA Pagar Alam	40	{kursi_tunggu,atap,papan_info}	\N	\N	t	2026-03-30 18:41:48.677268	0101000020E6100000265305A3924E5A402497FF907E7B15C0
3	Halte Sukaraja	HLT-003	bus	Jl. Soekarno Hatta	30	{kursi_tunggu,atap}	\N	\N	t	2026-03-30 18:41:48.677268	0101000020E610000072F90FE9B74F5A40ED9E3C2CD49A15C0
4	Halte Kemiling	HLT-004	angkot	Jl. Imam Bonjol	20	{kursi_tunggu}	\N	\N	t	2026-03-30 18:41:48.677268	0101000020E6100000D93D7958A84D5A40917EFB3A708E15C0
5	Halte Teluk Betung	HLT-005	brt	Jl. Laksamana Malahayati	45	{kursi_tunggu,atap,papan_info,toilet}	\N	\N	t	2026-03-30 18:41:48.677268	0101000020E61000003E7958A835515A4020D26F5F07CE15C0
6	Halte Panjang	HLT-006	bus	Jl. Yos Sudarso	35	{kursi_tunggu,atap}	\N	\N	t	2026-03-30 18:41:48.677268	0101000020E610000088635DDC46535A40AA60545227E015C0
7	Halte Way Halim	HLT-007	angkot	Jl. Sultan Agung	25	{kursi_tunggu,atap}	\N	\N	t	2026-03-30 18:41:48.677268	0101000020E6100000EEEBC03923525A402E90A0F831A615C0
8	Halte Kedaton	HLT-008	brt	Jl. Teuku Umar	40	{kursi_tunggu,atap,papan_info}	\N	\N	t	2026-03-30 18:41:48.677268	0101000020E610000055302AA913505A408716D9CEF79315C0
9	Halte Labuhan Ratu	HLT-009	bus	Jl. Pulau Damar	30	{kursi_tunggu,atap}	\N	\N	t	2026-03-30 18:41:48.677268	0101000020E61000002C6519E2584F5A400DE02D90A07815C0
10	Halte Tanjung Senang	HLT-010	angkot	Jl. Ryacudu	20	{kursi_tunggu}	\N	\N	t	2026-03-30 18:41:48.677268	0101000020E6100000C4B12E6EA3515A40462575029A8815C0
11	Halte Sukarame	HLT-011	brt	Jl. Endro Suratmin	45	{kursi_tunggu,atap,papan_info}	\N	\N	t	2026-03-30 18:41:48.677268	0101000020E6100000022B8716D9525A40CE1951DA1B7C15C0
12	Halte Korpri	HLT-012	bus	Jl. Korpri Raya	35	{kursi_tunggu,atap}	\N	\N	t	2026-03-30 18:41:48.677268	0101000020E61000005D6DC5FEB2535A40B459F5B9DA8A15C0
13	Halte Gedong Air	HLT-013	angkot	Jl. Ikan Kakap	25	{kursi_tunggu}	\N	\N	t	2026-03-30 18:41:48.677268	0101000020E610000016FBCBEEC94F5A406F8104C58FB115C0
14	Halte Enggal	HLT-014	brt	Jl. Kartini	50	{kursi_tunggu,atap,papan_info,cctv}	\N	\N	t	2026-03-30 18:41:48.677268	0101000020E6100000CD3B4ED191505A40772D211FF4AC15C0
15	Halte Kaliawi	HLT-015	bus	Jl. Ikan Tongkol	30	{kursi_tunggu,atap}	\N	\N	t	2026-03-30 18:41:48.677268	0101000020E61000009C33A2B437505A4055C1A8A44EC015C0
16	Halte Sumur Batu	HLT-016	angkot	Jl. Wolter Monginsidi	20	{kursi_tunggu}	\N	\N	t	2026-03-30 18:41:48.677268	0101000020E61000009A779CA223515A404D158C4AEAC415C0
17	Halte Bumi Waras	HLT-017	brt	Jl. Ikan Hiu	40	{kursi_tunggu,atap,papan_info}	\N	\N	t	2026-03-30 18:41:48.677268	0101000020E6100000DAACFA5C6D515A408E06F01648D015C0
18	Halte Sukabumi	HLT-018	bus	Jl. Pangeran Antasari	35	{kursi_tunggu,atap}	\N	\N	t	2026-03-30 18:41:48.677268	0101000020E6100000A5BDC117264F5A406D567DAEB6A215C0
19	Halte Langkapura	HLT-019	angkot	Jl. Pramuka	25	{kursi_tunggu}	\N	\N	t	2026-03-30 18:41:48.677268	0101000020E61000000B462575024E5A40ED9E3C2CD49A15C0
20	Halte Segala Mider	HLT-020	brt	Jl. Cut Nyak Dien	45	{kursi_tunggu,atap,papan_info}	\N	\N	t	2026-03-30 18:41:48.677268	0101000020E610000091ED7C3F35525A4014D044D8F0B415C0
21	Halte ITERA	HLT-021	brt	Jl. Terusan Ryacudu	50	{kursi_tunggu,atap,papan_info,wifi}	\N	\N	t	2026-03-30 18:41:48.677268	0101000020E610000087A757CA32545A4003098A1F636E15C0
22	Halte Unila	HLT-022	brt	Jl. Prof. Sumantri Brojonegoro	50	{kursi_tunggu,atap,papan_info}	\N	\N	t	2026-03-30 18:41:48.677268	0101000020E610000074B515FBCB4E5A4044FAEDEBC07915C0
23	Halte Pasar Tengah	HLT-023	bus	Jl. Ikan Bawal	35	{kursi_tunggu,atap}	\N	\N	t	2026-03-30 18:41:48.677268	0101000020E6100000226C787AA5505A40DDB5847CD0B315C0
24	Halte Bambu Kuning	HLT-024	angkot	Jl. Bambu Kuning	30	{kursi_tunggu,atap}	\N	\N	t	2026-03-30 18:41:48.677268	0101000020E61000002A3A92CB7F505A4076711B0DE0AD15C0
25	Halte Simpur Center	HLT-025	brt	Jl. Jendral Sudirman	45	{kursi_tunggu,atap,papan_info,cctv}	\N	\N	t	2026-03-30 18:41:48.677268	0101000020E61000000D71AC8BDB505A409CC420B072A815C0
\.


--
-- TOC entry 6145 (class 0 OID 20020)
-- Dependencies: 240
-- Data for Name: kecelakaan; Type: TABLE DATA; Schema: transportasi; Owner: postgres
--

COPY transportasi.kecelakaan (id, tanggal, waktu, jenis_kecelakaan, jumlah_korban, jumlah_kendaraan, penyebab, kondisi_jalan, kondisi_cuaca, keterangan, created_at, geom) FROM stdin;
1	2024-01-15	08:30:00	sedang	2	2	Tabrakan beruntun	baik	cerah	\N	2026-03-30 18:42:19.457792	0101000020E6100000C66D3480B7505A40D50968226CB815C0
2	2024-01-20	17:45:00	ringan	1	1	Motor tergelincir	berlubang	hujan	\N	2026-03-30 18:42:19.457792	0101000020E61000009C33A2B437505A40D3DEE00B93A915C0
3	2024-02-03	22:15:00	berat	3	3	Pengemudi mengantuk	baik	berkabut	\N	2026-03-30 18:42:19.457792	0101000020E6100000C4B12E6EA3515A4019E25817B79115C0
4	2024-02-10	06:00:00	ringan	0	2	Menyalip sembarangan	baik	cerah	\N	2026-03-30 18:42:19.457792	0101000020E61000007B832F4CA64E5A404ED1915CFE8315C0
5	2024-02-18	14:30:00	sedang	2	2	Rem blong	rusak	cerah	\N	2026-03-30 18:42:19.457792	0101000020E61000009A779CA223515A4020D26F5F07CE15C0
6	2024-03-05	19:00:00	berat	4	2	Melawan arah	baik	hujan	\N	2026-03-30 18:42:19.457792	0101000020E610000072F90FE9B74F5A40363CBD5296A115C0
7	2024-03-12	11:30:00	ringan	1	2	Tidak jaga jarak	baik	cerah	\N	2026-03-30 18:42:19.457792	0101000020E6100000022B8716D9525A40AA8251499D8015C0
8	2024-03-20	16:45:00	fatal	1	2	Kecepatan tinggi	baik	cerah	\N	2026-03-30 18:42:19.457792	0101000020E6100000696FF085C9505A408104C58F31B715C0
9	2024-04-01	07:15:00	sedang	2	3	Tabrakan di persimpangan	baik	berkabut	\N	2026-03-30 18:42:19.457792	0101000020E6100000CD3B4ED191505A40772D211FF4AC15C0
10	2024-04-08	20:30:00	ringan	1	1	Menabrak pembatas jalan	baik	hujan	\N	2026-03-30 18:42:19.457792	0101000020E6100000EEEBC03923525A406F8104C58FB115C0
11	2024-04-15	13:00:00	berat	3	2	Truk hilang kendali	rusak	cerah	\N	2026-03-30 18:42:19.457792	0101000020E610000088635DDC46535A40F38E537424D715C0
12	2024-04-22	09:45:00	sedang	2	2	Motor vs mobil	berlubang	cerah	\N	2026-03-30 18:42:19.457792	0101000020E6100000A5BDC117264F5A4050FC1873D79215C0
13	2024-05-01	18:00:00	ringan	1	2	Saling senggol	baik	cerah	\N	2026-03-30 18:42:19.457792	0101000020E610000055302AA913505A402C6519E2589715C0
14	2024-05-10	23:30:00	fatal	2	2	Mabuk	baik	cerah	\N	2026-03-30 18:42:19.457792	0101000020E61000003E7958A835515A40F163CC5D4BC815C0
15	2024-05-18	10:15:00	sedang	2	3	Ban pecah	baik	hujan	\N	2026-03-30 18:42:19.457792	0101000020E6100000265305A3924E5A40AA8251499D8015C0
16	2024-06-02	15:30:00	ringan	1	2	Tidak fokus	baik	cerah	\N	2026-03-30 18:42:19.457792	0101000020E6100000226C787AA5505A40772D211FF4AC15C0
17	2024-06-15	08:00:00	sedang	2	2	Lampu merah dilanggar	baik	cerah	\N	2026-03-30 18:42:19.457792	0101000020E61000000D71AC8BDB505A409CC420B072A815C0
18	2024-06-28	21:00:00	berat	3	2	Tabrak lari	baik	hujan	\N	2026-03-30 18:42:19.457792	0101000020E6100000DAACFA5C6D515A4055C1A8A44EC015C0
19	2024-07-05	12:30:00	ringan	0	2	Parkir sembarangan	baik	cerah	\N	2026-03-30 18:42:19.457792	0101000020E61000002A3A92CB7F505A40014D840D4FAF15C0
20	2024-07-12	17:00:00	sedang	2	3	U-turn sembarangan	baik	cerah	\N	2026-03-30 18:42:19.457792	0101000020E610000091ED7C3F35525A406D567DAEB6A215C0
\.


--
-- TOC entry 6147 (class 0 OID 20032)
-- Dependencies: 242
-- Data for Name: parkir; Type: TABLE DATA; Schema: transportasi; Owner: postgres
--

COPY transportasi.parkir (id, nama, jenis, kapasitas, tarif_per_jam, jam_buka, jam_tutup, pengelola, created_at, geom) FROM stdin;
1	Parkir Mall Kartini	campuran	500	3000	08:00:00	22:00:00	PT Mall Kartini	2026-03-30 18:42:29.557448	0101000020E6100000696FF085C9505A40401361C3D3AB15C0
2	Parkir Pasar Tengah	campuran	200	2000	06:00:00	18:00:00	Pemkot Bandar Lampung	2026-03-30 18:42:29.557448	0101000020E6100000CD3B4ED191505A406F8104C58FB115C0
3	Parkir RSUD Abdul Moeloek	campuran	150	2000	00:00:00	23:59:00	RSUD Abdul Moeloek	2026-03-30 18:42:29.557448	0101000020E61000009C33A2B437505A40D3DEE00B93A915C0
4	Parkir Stasiun Tanjung Karang	campuran	300	2500	04:00:00	23:00:00	PT KAI	2026-03-30 18:42:29.557448	0101000020E6100000C66D3480B7505A4014D044D8F0B415C0
5	Parkir Chandra Superstore	campuran	400	2000	09:00:00	21:30:00	Chandra Group	2026-03-30 18:42:29.557448	0101000020E6100000B0726891ED505A409CC420B072A815C0
6	Parkir Motor Pasar Bambu Kuning	motor	100	1000	06:00:00	17:00:00	Pemkot Bandar Lampung	2026-03-30 18:42:29.557448	0101000020E61000002A3A92CB7F505A40014D840D4FAF15C0
7	Parkir Unila	campuran	600	1500	06:00:00	22:00:00	Universitas Lampung	2026-03-30 18:42:29.557448	0101000020E610000074B515FBCB4E5A4044FAEDEBC07915C0
8	Parkir ITERA	campuran	400	1500	06:00:00	22:00:00	Institut Teknologi Sumatera	2026-03-30 18:42:29.557448	0101000020E610000087A757CA32545A4003098A1F636E15C0
9	Parkir Simpur Center	campuran	350	3000	09:00:00	22:00:00	PT Simpur Center	2026-03-30 18:42:29.557448	0101000020E61000000D71AC8BDB505A409CC420B072A815C0
10	Parkir Central Plaza	campuran	450	3000	09:00:00	22:00:00	PT Central Plaza	2026-03-30 18:42:29.557448	0101000020E6100000226C787AA5505A40772D211FF4AC15C0
11	Parkir Motor Enggal	motor	80	1000	06:00:00	18:00:00	Pemkot Bandar Lampung	2026-03-30 18:42:29.557448	0101000020E6100000CD3B4ED191505A40772D211FF4AC15C0
12	Parkir Transmart	campuran	500	2500	09:00:00	22:00:00	PT Trans Retail	2026-03-30 18:42:29.557448	0101000020E6100000C4B12E6EA3515A4019E25817B79115C0
\.


--
-- TOC entry 6141 (class 0 OID 19995)
-- Dependencies: 236
-- Data for Name: rute; Type: TABLE DATA; Schema: transportasi; Owner: postgres
--

COPY transportasi.rute (id, kode_rute, nama_rute, jenis, warna, panjang_km, estimasi_waktu_menit, tarif, aktif, created_at, geom) FROM stdin;
1	RT-001	Rajabasa - Tanjung Karang	brt	#FF0000	8.50	25	5000	t	2026-03-30 18:41:58.527237	0102000020E610000006000000265305A3924E5A402497FF907E7B15C074B515FBCB4E5A4044FAEDEBC07915C02C6519E2584F5A400AD7A3703D8A15C055302AA913505A408716D9CEF79315C0CD3B4ED191505A40772D211FF4AC15C0A2B437F8C2505A400F9C33A2B4B715C0
2	RT-002	Tanjung Karang - Teluk Betung	brt	#00FF00	6.20	20	5000	t	2026-03-30 18:41:58.527237	0102000020E610000005000000A2B437F8C2505A400F9C33A2B4B715C00D71AC8BDB505A409CC420B072A815C054742497FF505A40E78C28ED0DBE15C09A779CA223515A404D158C4AEAC415C03E7958A835515A4020D26F5F07CE15C0
3	RT-003	Kemiling - Sukarame	bus	#0000FF	12.30	40	4000	t	2026-03-30 18:41:58.527237	0102000020E610000006000000D93D7958A84D5A40917EFB3A708E15C0A5BDC117264F5A40D8F0F44A598615C0CD3B4ED191505A40AA8251499D8015C0EEEBC03923525A40CE1951DA1B7C15C0022B8716D9525A40CE1951DA1B7C15C05D6DC5FEB2535A40B459F5B9DA8A15C0
4	RT-004	Way Halim - Panjang	bus	#FFFF00	9.80	35	4000	t	2026-03-30 18:41:58.527237	0102000020E610000005000000EEEBC03923525A402E90A0F831A615C091ED7C3F35525A4014D044D8F0B415C035EF384547525A40C3F5285C8FC215C018265305A3525A408E06F01648D015C088635DDC46535A40AA60545227E015C0
5	RT-005	Kedaton Circular	angkot	#FF00FF	7.50	30	3000	t	2026-03-30 18:41:58.527237	0102000020E61000000600000055302AA913505A408716D9CEF79315C072F90FE9B74F5A40ED9E3C2CD49A15C02C6519E2584F5A406D567DAEB6A215C0A5BDC117264F5A406D567DAEB6A215C072F90FE9B74F5A408716D9CEF79315C055302AA913505A408716D9CEF79315C0
6	RT-006	ITERA - Tanjung Karang	brt	#00FFFF	10.50	35	5000	t	2026-03-30 18:41:58.527237	0102000020E61000000400000087A757CA32545A4003098A1F636E15C0022B8716D9525A40CE1951DA1B7C15C0C4B12E6EA3515A40462575029A8815C0A2B437F8C2505A400F9C33A2B4B715C0
7	RT-007	Unila - Teluk Betung	bus	#FFA500	11.20	40	4000	t	2026-03-30 18:41:58.527237	0102000020E61000000400000074B515FBCB4E5A4044FAEDEBC07915C072F90FE9B74F5A40ED9E3C2CD49A15C0CD3B4ED191505A40772D211FF4AC15C03E7958A835515A4020D26F5F07CE15C0
8	RT-008	Sukarame - Panjang	bus	#800080	13.50	45	4500	t	2026-03-30 18:41:58.527237	0102000020E610000004000000022B8716D9525A40CE1951DA1B7C15C0EEEBC03923525A402E90A0F831A615C0DAACFA5C6D515A408E06F01648D015C088635DDC46535A40AA60545227E015C0
\.


--
-- TOC entry 6143 (class 0 OID 20008)
-- Dependencies: 238
-- Data for Name: wilayah; Type: TABLE DATA; Schema: transportasi; Owner: postgres
--

COPY transportasi.wilayah (id, kode_wilayah, nama, tipe, populasi, luas_km2, created_at, geom) FROM stdin;
1	3571010	Tanjung Karang Pusat	kecamatan	85000	4.05	2026-03-30 18:42:09.2424	0103000020E610000001000000050000000000000000505A40A4703D0AD7A315C0E17A14AE47515A40A4703D0AD7A315C0E17A14AE47515A40C3F5285C8FC215C00000000000505A40C3F5285C8FC215C00000000000505A40A4703D0AD7A315C0
2	3571020	Tanjung Karang Barat	kecamatan	72000	14.99	2026-03-30 18:42:09.2424	0103000020E610000001000000050000001F85EB51B84E5A4085EB51B81E8515C00000000000505A4085EB51B81E8515C00000000000505A40AE47E17A14AE15C01F85EB51B84E5A40AE47E17A14AE15C01F85EB51B84E5A4085EB51B81E8515C0
3	3571030	Teluk Betung Selatan	kecamatan	45000	3.79	2026-03-30 18:42:09.2424	0103000020E61000000100000005000000713D0AD7A3505A40C3F5285C8FC215C052B81E85EB515A40C3F5285C8FC215C052B81E85EB515A40E17A14AE47E115C0713D0AD7A3505A40E17A14AE47E115C0713D0AD7A3505A40C3F5285C8FC215C0
4	3571040	Rajabasa	kecamatan	95000	13.02	2026-03-30 18:42:09.2424	0103000020E610000001000000050000003D0AD7A3704D5A40713D0AD7A37015C08FC2F5285C4F5A40713D0AD7A37015C08FC2F5285C4F5A408FC2F5285C8F15C03D0AD7A3704D5A408FC2F5285C8F15C03D0AD7A3704D5A40713D0AD7A37015C0
5	3571050	Sukarame	kecamatan	88000	14.75	2026-03-30 18:42:09.2424	0103000020E6100000010000000500000052B81E85EB515A40713D0AD7A37015C014AE47E17A545A40713D0AD7A37015C014AE47E17A545A409A999999999915C052B81E85EB515A409A999999999915C052B81E85EB515A40713D0AD7A37015C0
6	3571060	Kedaton	kecamatan	78000	5.23	2026-03-30 18:42:09.2424	0103000020E610000001000000050000008FC2F5285C4F5A4085EB51B81E8515C0713D0AD7A3505A4085EB51B81E8515C0713D0AD7A3505A40A4703D0AD7A315C08FC2F5285C4F5A40A4703D0AD7A315C08FC2F5285C4F5A4085EB51B81E8515C0
7	3571070	Way Halim	kecamatan	82000	5.35	2026-03-30 18:42:09.2424	0103000020E61000000100000005000000E17A14AE47515A409A999999999915C03333333333535A409A999999999915C03333333333535A40B81E85EB51B815C0E17A14AE47515A40B81E85EB51B815C0E17A14AE47515A409A999999999915C0
8	3571080	Panjang	kecamatan	65000	8.92	2026-03-30 18:42:09.2424	0103000020E61000000100000005000000C3F5285C8F525A40D7A3703D0AD715C014AE47E17A545A40D7A3703D0AD715C014AE47E17A545A40F6285C8FC2F515C0C3F5285C8F525A40F6285C8FC2F515C0C3F5285C8F525A40D7A3703D0AD715C0
\.


--
-- TOC entry 6180 (class 0 OID 0)
-- Dependencies: 253
-- Name: deteksi_objek_id_seq; Type: SEQUENCE SET; Schema: pertanian; Owner: postgres
--

SELECT pg_catalog.setval('pertanian.deteksi_objek_id_seq', 1, false);


--
-- TOC entry 6181 (class 0 OID 0)
-- Dependencies: 249
-- Name: hama_penyakit_id_seq; Type: SEQUENCE SET; Schema: pertanian; Owner: postgres
--

SELECT pg_catalog.setval('pertanian.hama_penyakit_id_seq', 15, true);


--
-- TOC entry 6182 (class 0 OID 0)
-- Dependencies: 251
-- Name: irigasi_id_seq; Type: SEQUENCE SET; Schema: pertanian; Owner: postgres
--

SELECT pg_catalog.setval('pertanian.irigasi_id_seq', 7, true);


--
-- TOC entry 6183 (class 0 OID 0)
-- Dependencies: 247
-- Name: kelompok_tani_id_seq; Type: SEQUENCE SET; Schema: pertanian; Owner: postgres
--

SELECT pg_catalog.setval('pertanian.kelompok_tani_id_seq', 16, true);


--
-- TOC entry 6184 (class 0 OID 0)
-- Dependencies: 245
-- Name: kios_pupuk_id_seq; Type: SEQUENCE SET; Schema: pertanian; Owner: postgres
--

SELECT pg_catalog.setval('pertanian.kios_pupuk_id_seq', 8, true);


--
-- TOC entry 6185 (class 0 OID 0)
-- Dependencies: 243
-- Name: lahan_id_seq; Type: SEQUENCE SET; Schema: pertanian; Owner: postgres
--

SELECT pg_catalog.setval('pertanian.lahan_id_seq', 15, true);


--
-- TOC entry 6186 (class 0 OID 0)
-- Dependencies: 225
-- Name: fasilitas_publik_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.fasilitas_publik_id_seq', 1, false);


--
-- TOC entry 6187 (class 0 OID 0)
-- Dependencies: 227
-- Name: topology_id_seq; Type: SEQUENCE SET; Schema: topology; Owner: postgres
--

SELECT pg_catalog.setval('topology.topology_id_seq', 1, false);


--
-- TOC entry 6188 (class 0 OID 0)
-- Dependencies: 233
-- Name: halte_id_seq; Type: SEQUENCE SET; Schema: transportasi; Owner: postgres
--

SELECT pg_catalog.setval('transportasi.halte_id_seq', 25, true);


--
-- TOC entry 6189 (class 0 OID 0)
-- Dependencies: 239
-- Name: kecelakaan_id_seq; Type: SEQUENCE SET; Schema: transportasi; Owner: postgres
--

SELECT pg_catalog.setval('transportasi.kecelakaan_id_seq', 20, true);


--
-- TOC entry 6190 (class 0 OID 0)
-- Dependencies: 241
-- Name: parkir_id_seq; Type: SEQUENCE SET; Schema: transportasi; Owner: postgres
--

SELECT pg_catalog.setval('transportasi.parkir_id_seq', 12, true);


--
-- TOC entry 6191 (class 0 OID 0)
-- Dependencies: 235
-- Name: rute_id_seq; Type: SEQUENCE SET; Schema: transportasi; Owner: postgres
--

SELECT pg_catalog.setval('transportasi.rute_id_seq', 8, true);


--
-- TOC entry 6192 (class 0 OID 0)
-- Dependencies: 237
-- Name: wilayah_id_seq; Type: SEQUENCE SET; Schema: transportasi; Owner: postgres
--

SELECT pg_catalog.setval('transportasi.wilayah_id_seq', 8, true);


--
-- TOC entry 5978 (class 2606 OID 20105)
-- Name: deteksi_objek deteksi_objek_pkey; Type: CONSTRAINT; Schema: pertanian; Owner: postgres
--

ALTER TABLE ONLY pertanian.deteksi_objek
    ADD CONSTRAINT deteksi_objek_pkey PRIMARY KEY (id);


--
-- TOC entry 5972 (class 2606 OID 20085)
-- Name: hama_penyakit hama_penyakit_pkey; Type: CONSTRAINT; Schema: pertanian; Owner: postgres
--

ALTER TABLE ONLY pertanian.hama_penyakit
    ADD CONSTRAINT hama_penyakit_pkey PRIMARY KEY (id);


--
-- TOC entry 5976 (class 2606 OID 20095)
-- Name: irigasi irigasi_pkey; Type: CONSTRAINT; Schema: pertanian; Owner: postgres
--

ALTER TABLE ONLY pertanian.irigasi
    ADD CONSTRAINT irigasi_pkey PRIMARY KEY (id);


--
-- TOC entry 5970 (class 2606 OID 20074)
-- Name: kelompok_tani kelompok_tani_pkey; Type: CONSTRAINT; Schema: pertanian; Owner: postgres
--

ALTER TABLE ONLY pertanian.kelompok_tani
    ADD CONSTRAINT kelompok_tani_pkey PRIMARY KEY (id);


--
-- TOC entry 5967 (class 2606 OID 20064)
-- Name: kios_pupuk kios_pupuk_pkey; Type: CONSTRAINT; Schema: pertanian; Owner: postgres
--

ALTER TABLE ONLY pertanian.kios_pupuk
    ADD CONSTRAINT kios_pupuk_pkey PRIMARY KEY (id);


--
-- TOC entry 5962 (class 2606 OID 20052)
-- Name: lahan lahan_kode_lahan_key; Type: CONSTRAINT; Schema: pertanian; Owner: postgres
--

ALTER TABLE ONLY pertanian.lahan
    ADD CONSTRAINT lahan_kode_lahan_key UNIQUE (kode_lahan);


--
-- TOC entry 5964 (class 2606 OID 20050)
-- Name: lahan lahan_pkey; Type: CONSTRAINT; Schema: pertanian; Owner: postgres
--

ALTER TABLE ONLY pertanian.lahan
    ADD CONSTRAINT lahan_pkey PRIMARY KEY (id);


--
-- TOC entry 5930 (class 2606 OID 19680)
-- Name: fasilitas_publik fasilitas_publik_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fasilitas_publik
    ADD CONSTRAINT fasilitas_publik_pkey PRIMARY KEY (id);


--
-- TOC entry 5940 (class 2606 OID 19992)
-- Name: halte halte_kode_key; Type: CONSTRAINT; Schema: transportasi; Owner: postgres
--

ALTER TABLE ONLY transportasi.halte
    ADD CONSTRAINT halte_kode_key UNIQUE (kode);


--
-- TOC entry 5942 (class 2606 OID 19990)
-- Name: halte halte_pkey; Type: CONSTRAINT; Schema: transportasi; Owner: postgres
--

ALTER TABLE ONLY transportasi.halte
    ADD CONSTRAINT halte_pkey PRIMARY KEY (id);


--
-- TOC entry 5956 (class 2606 OID 20030)
-- Name: kecelakaan kecelakaan_pkey; Type: CONSTRAINT; Schema: transportasi; Owner: postgres
--

ALTER TABLE ONLY transportasi.kecelakaan
    ADD CONSTRAINT kecelakaan_pkey PRIMARY KEY (id);


--
-- TOC entry 5959 (class 2606 OID 20040)
-- Name: parkir parkir_pkey; Type: CONSTRAINT; Schema: transportasi; Owner: postgres
--

ALTER TABLE ONLY transportasi.parkir
    ADD CONSTRAINT parkir_pkey PRIMARY KEY (id);


--
-- TOC entry 5946 (class 2606 OID 20006)
-- Name: rute rute_kode_rute_key; Type: CONSTRAINT; Schema: transportasi; Owner: postgres
--

ALTER TABLE ONLY transportasi.rute
    ADD CONSTRAINT rute_kode_rute_key UNIQUE (kode_rute);


--
-- TOC entry 5948 (class 2606 OID 20004)
-- Name: rute rute_pkey; Type: CONSTRAINT; Schema: transportasi; Owner: postgres
--

ALTER TABLE ONLY transportasi.rute
    ADD CONSTRAINT rute_pkey PRIMARY KEY (id);


--
-- TOC entry 5951 (class 2606 OID 20018)
-- Name: wilayah wilayah_kode_wilayah_key; Type: CONSTRAINT; Schema: transportasi; Owner: postgres
--

ALTER TABLE ONLY transportasi.wilayah
    ADD CONSTRAINT wilayah_kode_wilayah_key UNIQUE (kode_wilayah);


--
-- TOC entry 5953 (class 2606 OID 20016)
-- Name: wilayah wilayah_pkey; Type: CONSTRAINT; Schema: transportasi; Owner: postgres
--

ALTER TABLE ONLY transportasi.wilayah
    ADD CONSTRAINT wilayah_pkey PRIMARY KEY (id);


--
-- TOC entry 5979 (class 1259 OID 20117)
-- Name: idx_deteksi_geom; Type: INDEX; Schema: pertanian; Owner: postgres
--

CREATE INDEX idx_deteksi_geom ON pertanian.deteksi_objek USING gist (geom);


--
-- TOC entry 5973 (class 1259 OID 20115)
-- Name: idx_hama_geom; Type: INDEX; Schema: pertanian; Owner: postgres
--

CREATE INDEX idx_hama_geom ON pertanian.hama_penyakit USING gist (geom);


--
-- TOC entry 5974 (class 1259 OID 20116)
-- Name: idx_irigasi_geom; Type: INDEX; Schema: pertanian; Owner: postgres
--

CREATE INDEX idx_irigasi_geom ON pertanian.irigasi USING gist (geom);


--
-- TOC entry 5965 (class 1259 OID 20113)
-- Name: idx_kios_geom; Type: INDEX; Schema: pertanian; Owner: postgres
--

CREATE INDEX idx_kios_geom ON pertanian.kios_pupuk USING gist (geom);


--
-- TOC entry 5960 (class 1259 OID 20112)
-- Name: idx_lahan_geom; Type: INDEX; Schema: pertanian; Owner: postgres
--

CREATE INDEX idx_lahan_geom ON pertanian.lahan USING gist (geom);


--
-- TOC entry 5968 (class 1259 OID 20114)
-- Name: idx_poktan_geom; Type: INDEX; Schema: pertanian; Owner: postgres
--

CREATE INDEX idx_poktan_geom ON pertanian.kelompok_tani USING gist (geom);


--
-- TOC entry 5943 (class 1259 OID 20107)
-- Name: idx_halte_geom; Type: INDEX; Schema: transportasi; Owner: postgres
--

CREATE INDEX idx_halte_geom ON transportasi.halte USING gist (geom);


--
-- TOC entry 5954 (class 1259 OID 20110)
-- Name: idx_kecelakaan_geom; Type: INDEX; Schema: transportasi; Owner: postgres
--

CREATE INDEX idx_kecelakaan_geom ON transportasi.kecelakaan USING gist (geom);


--
-- TOC entry 5957 (class 1259 OID 20111)
-- Name: idx_parkir_geom; Type: INDEX; Schema: transportasi; Owner: postgres
--

CREATE INDEX idx_parkir_geom ON transportasi.parkir USING gist (geom);


--
-- TOC entry 5944 (class 1259 OID 20108)
-- Name: idx_rute_geom; Type: INDEX; Schema: transportasi; Owner: postgres
--

CREATE INDEX idx_rute_geom ON transportasi.rute USING gist (geom);


--
-- TOC entry 5949 (class 1259 OID 20109)
-- Name: idx_wilayah_geom; Type: INDEX; Schema: transportasi; Owner: postgres
--

CREATE INDEX idx_wilayah_geom ON transportasi.wilayah USING gist (geom);


-- Completed on 2026-03-30 20:18:16

--
-- PostgreSQL database dump complete
--

\unrestrict t8NksrNSvaoBeZaFdkffdUhS7wQCalicBgDeVGHxMgKnkqLm1GgY6A922VkC5w7

