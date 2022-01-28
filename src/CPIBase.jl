# types.jl - Type definitions and structure
import Base: show, summary, convert, getindex, eltype

# Tipo abstracto para definir contenedores del IPC
abstract type AbstractCPIBase{T <: AbstractFloat} end

# Tipos para los vectores de fechas
const DATETYPE = StepRange{Date, Month}

# El tipo B representa el tipo utilizado para almacenar los índices base. 
# Puede ser un tipo flotante, por ejemplo, Float64 o bien, si los datos 
# disponibles empiezan con índices diferentes a 100, un vector, Vector{Float64}, 
# por ejemplo

"""
    FullCPIBase{T, B} <: AbstractCPIBase{T}

Contenedor completo para datos del IPC de un país. Se representa por:
- Matriz de índices de precios `ipc` que incluye la fila con los índices del númbero base. 
- Matriz de variaciones intermensuales `v`. En las filas contiene los períodos y en las columnas contiene los gastos básicos.
- Vector de ponderaciones `w` de los gastos básicos.
- Fechas correspondientes `dates` (por meses).
"""
Base.@kwdef struct FullCPIBase{T, B} <: AbstractCPIBase{T}
    ipc::Matrix{T}
    v::Matrix{T}
    w::Vector{T}
    dates::DATETYPE
    baseindex::B

    function FullCPIBase(ipc::Matrix{T}, v::Matrix{T}, w::Vector{T}, dates::DATETYPE, baseindex::B) where {T, B}
        size(ipc, 2) == size(v, 2) || throw(ArgumentError("número de columnas debe coincidir entre matriz de índices y variaciones"))
        size(ipc, 2) == length(w) || throw(ArgumentError("número de columnas debe coincidir con vector de ponderaciones"))
        size(ipc, 1) == size(v, 1) == length(dates) || throw(ArgumentError("número de filas de `ipc` debe coincidir con vector de fechas"))
        new{T, B}(ipc, v, w, dates, baseindex)
    end
end


"""
    IndexCPIBase{T, B} <: AbstractCPIBase{T}

Contenedor genérico de índices de precios del IPC de un país. Se representa por:
- Matriz de índices de precios `ipc` que incluye la fila con los índices del númbero base. 
- Vector de ponderaciones `w` de los gastos básicos.
- Fechas correspondientes `dates` (por meses).
"""
Base.@kwdef struct IndexCPIBase{T, B} <: AbstractCPIBase{T}
    ipc::Matrix{T}
    w::Vector{T}
    dates::DATETYPE
    baseindex::B

    function IndexCPIBase(ipc::Matrix{T}, w::Vector{T}, dates::DATETYPE, baseindex::B) where {T, B}
        size(ipc, 2) == length(w) || throw(ArgumentError("número de columnas debe coincidir con vector de ponderaciones"))
        size(ipc, 1) == length(dates) || throw(ArgumentError("número de filas debe coincidir con vector de fechas"))
        new{T, B}(ipc, w, dates, baseindex)
    end
end


"""
    VarCPIBase{T, B} <: AbstractCPIBase{T}

Contenedor genérico para de variaciones intermensuales de índices de precios del IPC de un país. Se representa por:
- Matriz de variaciones intermensuales `v`. En las filas contiene los períodos y en las columnas contiene los gastos básicos.
- Vector de ponderaciones `w` de los gastos básicos.
- Fechas correspondientes `dates` (por meses).
"""
Base.@kwdef struct VarCPIBase{T, B} <: AbstractCPIBase{T}
    v::Matrix{T}
    w::Vector{T}
    dates::DATETYPE
    baseindex::B

    function VarCPIBase(v::Matrix{T}, w::Vector{T}, dates::DATETYPE, baseindex::B) where {T, B}
        size(v, 2) == length(w) || throw(ArgumentError("número de columnas debe coincidir con vector de ponderaciones"))
        size(v, 1) == length(dates) || throw(ArgumentError("número de filas debe coincidir con vector de fechas"))
        new{T, B}(v, w, dates, baseindex)
    end
end


## Constructores
# Los constructores entre tipos crean copias y asignan nueva memoria

function _getbaseindex(baseindex)
    if length(unique(baseindex)) == 1
        return baseindex[1]
    end
    baseindex
end

"""
    FullCPIBase(df::DataFrame, gb::DataFrame)

Este constructor devuelve una estructura `FullCPIBase` a partir de los 
DataFrames de índices de precios `df` y de descripción de los gastos básicos
`gb`. 
- El DataFrame `df` posee la siguiente estructura: 
    - Contiene en la primera columna las fechas o períodos de los datos. En las
      siguientes columnas, debe contener los códigos de cada una de las
      categorías o gastos básicos de la estructura del IPC. 
    - En las filas del DataFrame contiene los períodos por meses. 
    - Un ejemplo de cómo puede verse este DataFrame es el siguiente: 
```
121×219 DataFrame
 Row │ Fecha       _011111  _011121  _011131  _011141  _011 ⋯
     │ Date        Float64  Float64  Float64  Float64  Floa ⋯
─────┼───────────────────────────────────────────────────────   
   1 │ 2000-12-01   100.0    100.0    100.0    100.0    100 ⋯   
   2 │ 2001-01-01   100.55   103.23   101.66   106.47   100  
   3 │ 2001-02-01   101.47   104.82   102.73   108.38   101  
   4 │ 2001-03-01   101.44   107.74   104.9    103.76   101  
   5 │ 2001-04-01   101.91   107.28   106.19   107.83   101 ⋯   
   6 │ 2001-05-01   102.77   106.12   106.9    109.16   101  
   7 │ 2001-06-01   103.23   109.04   107.4    112.13   102  
   8 │ 2001-07-01   104.35   112.72   107.96   117.19   105  
   9 │ 2001-08-01   106.18   116.69   110.18   119.91   106 ⋯  
  10 │ 2001-09-01   106.42   118.4    110.43   120.16   107  
  11 │ 2001-10-01   106.97   120.96   111.16   122.73   108  
  12 │ 2001-11-01   107.22   124.4    113.09   124.55   112  
  13 │ 2001-12-01   107.55   129.46   117.95   129.76   113 ⋯  
  14 │ 2002-01-01   107.77   135.75   120.16   134.5    113  
  ⋮  │     ⋮          ⋮        ⋮        ⋮        ⋮        ⋮ ⋱
```

- El DataFrame `gb` posee la siguiente estructura: 
    - La primera columna contiene los códigos de las columnas del DataFrame
      `df`. 
    - La segunda columna contiene el nombre o la descripción de cada una de las
      categorías en las columnas de `df`. 
    - Y finalmente, la tercer columna, debe contener las ponderaciones asociadas
      a cada una de las categorías o gastos básicos de las columnas de `df`.
    - Un ejemplo de cómo puede verse este DataFrame es el siguiente: 
```
218×3 DataFrame
 Row │ Codigo  GastoBasico
     │ String  String
─────┼──────────────────────────────────────────────
   1 │ 011111  Arroz
   2 │ 011121  Pan
   3 │ 011131  Pastas frescas y secas
   4 │ 011141  Productos de tortillería
   5 │ 011142  Productos de pastelería y rep…
   6 │ 011151  Maíz
   7 │ 011152  Otros cereales
   8 │ 011153  Harina de maíz
   9 │ 011154  Molienda de Maiz
  10 │ 011211  Carne bovina fresca, refrigerada…
  11 │ 011221  Carne de cerdo fresca, refrigera…
  12 │ 011231  Carne de aves fresca, refrigerad…
  13 │ 011241  Embutidos frescos o refrigerados…
  14 │ 011311  Pescado fresco o seco, refrigera…
  ⋮  │   ⋮                     ⋮                  ⋮
```
"""
function FullCPIBase(df::DataFrame, gb::DataFrame)
    # Obtener matriz de índices de precios
    ipc_mat = Matrix(df[!, 2:end])
    # Matrices de variaciones intermensuales de índices de precios
    v_mat = 100 .* (ipc_mat[2:end, :] ./ ipc_mat[1:end-1, :] .- 1)
    # Ponderación de gastos básicos o categorías
    w = gb[!, 3]
    # Actualización de fechas
    dates = df[2, 1]:Month(1):df[end, 1] 
    # Estructura de variaciones intermensuales de base del IPC
    return FullCPIBase(ipc_mat[2:end, :], v_mat, w, dates, _getbaseindex(ipc_mat[1, :]))
end


"""
    VarCPIBase(df::DataFrame, gb::DataFrame)

Este constructor devuelve una estructura `VarCPIBase` a partir del DataFrame 
de índices de precios `df`, que contiene en las columnas las categorías o gastos 
básicos del IPC y en las filas los períodos por meses. Las ponderaciones se obtienen 
de la estructura `gb`, en la tercera columna de ponderaciones.

Para conocer la estructura de los DataFrames necesarios, vea también: [`FullCPIBase`](@ref).
"""
function VarCPIBase(df::DataFrame, gb::DataFrame)
    # Obtener estructura completa
    cpi_base = FullCPIBase(df, gb)
    # Estructura de variaciones intermensuales de base del IPC
    VarCPIBase(cpi_base)
end

function VarCPIBase(base::FullCPIBase)
    nbase = deepcopy(base)
    VarCPIBase(nbase.v, nbase.w, nbase.dates, nbase.baseindex)
end

# Obtener VarCPIBase de IndexCPIBase con variaciones intermensuales
VarCPIBase(base::IndexCPIBase) = convert(VarCPIBase, deepcopy(base))

"""
    IndexCPIBase(df::DataFrame, gb::DataFrame)

Este constructor devuelve una estructura `IndexCPIBase` a partir del DataFrame 
de índices de precios `df`, que contiene en las columnas las categorías o gastos 
básicos del IPC y en las filas los períodos por meses. Las ponderaciones se obtienen 
de la estructura `gb`, en la tercera columna de ponderaciones.

Para conocer la estructura de los DataFrames necesarios, vea también: [`FullCPIBase`](@ref).
"""
function IndexCPIBase(df::DataFrame, gb::DataFrame)
    # Obtener estructura completa
    cpi_base = FullCPIBase(df, gb)
    # Estructura de índices de precios de base del IPC
    return IndexCPIBase(cpi_base)
end

function IndexCPIBase(base::FullCPIBase) 
    nbase = deepcopy(base)
    IndexCPIBase(nbase.ipc, nbase.w, nbase.dates, nbase.baseindex)
end

# Obtener IndexCPIBase de VarCPIBase con capitalización intermensual
IndexCPIBase(base::VarCPIBase) = convert(IndexCPIBase, deepcopy(base))

## Conversión

# Estos métodos sí crean copias a través de la función `convert` de los campos
convert(::Type{T}, base::VarCPIBase) where {T <: AbstractFloat} = 
    VarCPIBase(convert.(T, base.v), convert.(T, base.w), base.dates, convert.(T, base.baseindex))
convert(::Type{T}, base::IndexCPIBase) where {T <: AbstractFloat} = 
    IndexCPIBase(convert.(T, base.ipc), convert.(T, base.w), base.dates, convert.(T, base.baseindex))
convert(::Type{T}, base::FullCPIBase) where {T <: AbstractFloat} = 
    FullCPIBase(convert.(T, base.ipc), convert.(T, base.v), convert.(T, base.w), base.dates, convert.(T, base.baseindex))

# Estos métodos no crean copias, como se indica en la documentación: 
# > If T is a collection type and x a collection, the result of convert(T, x) 
# > may alias all or part of x.
# Al convertir de esta forma se muta la matriz de variaciones intermensuales y se
# devuelve el mismo tipo, pero sin asignar nueva memoria
function convert(::Type{IndexCPIBase}, base::VarCPIBase)
    vmat = base.v
    capitalize!(vmat, base.baseindex)
    IndexCPIBase(vmat, base.w, base.dates, base.baseindex)
end

function convert(::Type{VarCPIBase}, base::IndexCPIBase)
    ipcmat = base.ipc
    varinterm!(ipcmat, base.baseindex)
    VarCPIBase(ipcmat, base.w, base.dates, base.baseindex)
end

# Tipo de flotante del contenedor
eltype(::AbstractCPIBase{T}) where {T} = T


## Métodos para mostrar los tipos

function _formatdate(fecha)
    Dates.format(fecha, dateformat"u-yyyy")
end

function summary(io::IO, base::AbstractCPIBase)
    field = hasproperty(base, :v) ? :v : :ipc
    periodos, gastos = size(getproperty(base, field))
    print(io, typeof(base), ": ", periodos, " × ", gastos)
end

function show(io::IO, base::AbstractCPIBase)
    field = hasproperty(base, :v) ? :v : :ipc
    periodos, gastos = size(getproperty(base, field))
    print(io, typeof(base), ": ", periodos, " períodos × ", gastos, " gastos básicos ")
    datestart, dateend = _formatdate.((first(base.dates), last(base.dates)))
    print(io, datestart, "-", dateend)
end

"""
    periods(base::VarCPIBase)

Computa el número de períodos (meses) en las base de variaciones intermensuales. 
"""
periods(base::VarCPIBase) = size(base.v, 1)
