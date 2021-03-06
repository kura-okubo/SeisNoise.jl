import SeisIO: demean, demean!, taper, taper!,detrend, detrend!
export detrend, detrend!, taper, taper!, demean, demean!, bandpass, bandpass!
export bandstop, bandstop!, lowpass, lowpass!, highpass, highpass!
export phase, phase!, hanningwindow
# Signal processing functions for arrays (rather than SeisData or SeisChannel)

"""
    detrend!(X::AbstractArray{<:Union{Float32,Float64},1})

Remove linear trend from array `X` using least-squares regression.
"""
function detrend!(X::AbstractArray{<:Union{Float32,Float64},1})
    T = eltype(X)
    N = length(X)
    A = ones(T,N,2)
    A[:,1] .= range(T(1/N),T(1),length=N)
    coeff = A \ X
    X[:] .= X .- A *coeff
    return nothing
end
detrend(A::AbstractArray{<:Union{Float32,Float64},1}) = (U = deepcopy(A);
        detrend!(U);return U)

"""
    detrend!(X::AbstractArray{<:Union{Float32,Float64},2})

Remove linear trend from columns of `X` using least-squares regression.
"""
function detrend!(X::AbstractArray{<:Union{Float32,Float64},2})
    M,N = size(X)
    T = eltype(X)
    A = ones(T,M,2)
    A[:,1] .= range(T(1),stop=T(M)) ./ T(M)

    # solve least-squares through qr decomposition
    Q,R = qr(A)
    rq = inv(factorize(R)) * Q'
    for ii = 1:N
        coeff = rq * X[:,ii]
        X[:,ii] .-=  A *coeff
    end
    return nothing
end
detrend(A::AbstractArray{<:Union{Float32,Float64},2}) = (U = deepcopy(A);
        detrend!(U);return U)
detrend!(R::RawData) = detrend!(R.x)
detrend(R::RawData) = (U = deepcopy(R); detrend!(U.x); return U)

"""
    demean!(A::AbstractArray{<:Union{Float32,Float64},1})

Remove mean from array `A`.
"""
function demean!(A::AbstractArray{<:Union{Float32,Float64},1})
      μ = mean(A)
      for ii = 1:length(A)
        A[ii] -= μ
      end
  return nothing
end
demean(A::AbstractArray{<:Union{Float32,Float64},1}) = (U = deepcopy(A);
       demean!(U);return U)

"""
   demean!(A::AbstractArray{<:Union{Float32,Float64},2})

Remove mean from columns of array `A`.
"""
function demean!(A::AbstractArray{<:Union{Float32,Float64},2})
      M,N = size(A)
      for ii = 1:N
        μ = mean(A[:,ii])
        for jj = 1:M
          A[jj,ii] -= μ
        end
      end
  return nothing
end
demean(A::AbstractArray{<:Union{Float32,Float64},2}) = (U = deepcopy(A);
       demean!(U);return U)
demean!(R::RawData) = demean!(R.x)
demean(R::RawData) = (U = deepcopy(R); demean!(U.x); return U)

"""
   taper!(A,fs; max_percentage=0.05, max_length=20.)

Taper a time series `A` with sampling_rate `fs`.
Defaults to 'hann' window. Uses smallest of `max_percentage` * `fs`
or `max_length`.

# Arguments
- `A::AbstractArray`: Time series.
- `fs::Float64`: Sampling rate of time series `A`.
- `max_percentage::float`: Decimal percentage of taper at one end (ranging
   from 0. to 0.5).
- `max_length::Float64`: Length of taper at one end in seconds.
"""
function taper!(A::AbstractArray{<:Union{Float32,Float64},1}, fs::Float64;
                max_percentage::Float64=0.05, max_length::Float64=20.)
   N = length(A)
   T = eltype(A)
   wlen = min(Int(floor(N * max_percentage)), Int(floor(max_length * fs)), Int(
         floor(N/2)))
   taper_sides = [-hanningwindow(T,2 * wlen -1, zerophase=true) .+ T(1);T(0)]
   A[1:wlen] .= A[1:wlen] .* taper_sides[1:wlen]
   A[end-wlen+1:end] .= A[end-wlen+1:end] .* taper_sides[wlen+1:end]
   return nothing
end
taper(A::AbstractArray{<:Union{Float32,Float64},1}, fs::Float64;
      max_percentage::Float64=0.05, max_length::Float64=20.) = (U = deepcopy(A);
      taper!(U,fs,max_percentage=max_percentage,max_length=max_length);return U)

function taper!(A::AbstractArray{<:Union{Float32,Float64},2}, fs::Float64;
                max_percentage::Float64=0.05, max_length::Float64=20.)
   M,N = size(A)
   T = eltype(A)
   wlen = min(Int(floor(M * max_percentage)), Int(floor(max_length * fs)), Int(
         floor(M/2)))
   taper_sides = [-hanningwindow(T,2 * wlen -1, zerophase=true) .+ T(1);T(0)]
   for ii = 1:N
       A[1:wlen,ii] .= A[1:wlen,ii] .* taper_sides[1:wlen]
       A[end-wlen+1:end,ii] .= A[end-wlen+1:end,ii] .* taper_sides[wlen+1:end]
   end
   return nothing
end
taper(A::AbstractArray{<:Union{Float32,Float64},2}, fs::Float64;
       max_percentage::Float64=0.05,max_length::Float64=20.) = (U = deepcopy(A);
       taper!(U,fs,max_percentage=max_percentage,max_length=max_length);return U)
taper!(R::RawData; max_percentage::Float64=0.05,
       max_length::Float64=20.) = taper!(R.x,R.fs,max_percentage=max_percentage,
       max_length=max_length)
taper(R::RawData; max_percentage::Float64=0.05,
       max_length::Float64=20.) = (U = deepcopy(R); taper!(U.x,U.fs); return U)

"""
    phase!(A::AbstractArray)

Extract instantaneous phase from signal A.

For time series `A`, its analytic representation ``S = A + H(A)``, where
``H(A)`` is the Hilbert transform of `A`. The instantaneous phase ``e^{iθ}``
of `A` is given by dividing ``S`` by its modulus: ``e^{iθ} = \\frac{S}{|S|}``
For more information on Phase Cross-Correlation, see:
[Ventosa et al., 2019](https://pubs.geoscienceworld.org/ssa/srl/article-standard/570273/towards-the-processing-of-large-data-volumes-with).
"""
function phase!(A::AbstractArray)
    A .= angle.(hilbert(A))
    return nothing
end
phase(A::AbstractArray) = (U = deepcopy(A);phase!(U);return U)
phase!(R::RawData) = phase!(R.x)
phase(R::RawData) = (U = deepcopy(R);phase!(U.x);return U)


"""
   bandpass!(A,freqmin,freqmax,fs,corners=4,zerophase=false)

Butterworth-Bandpass Filter.

Filter data `A` from `freqmin` to `freqmax` using `corners` corners.

# Arguments
- `A::AbstractArray`: Data to filter
- `freqmin::Float64`: Pass band low corner frequency.
- `freqmax::Float64`: Pass band high corner frequency.
- `fs::Float64`: Sampling rate in Hz.
- `fs::Int`: Filter corners / order.
- `zerophase::Bool`: If True, apply filter once forwards and once backwards.
This results in twice the filter order but zero phase shift in
the resulting filtered trace.
"""
function bandpass!(A::AbstractArray{<:Union{Float32,Float64},1},
                   freqmin::Float64, freqmax::Float64, fs::Float64;
                   corners::Int=4, zerophase::Bool=false)
   fe = 0.5 * fs
   low = freqmin / fe
   high = freqmax / fe
   T = eltype(A)

   # warn if above Nyquist frequency
   if high - oneunit(high) > -1e-6
       @warn "Selected high corner frequency ($freqmax) of bandpass is at or
       above Nyquist ($fe). Applying a high-pass instead."
       highpass!(A,freqmin,fs,corners=corners,zerophase=zerophase)
       return nothing
   end

   # throw error if low above Nyquist frequency
   if low > 1
       ArgumentError("Selected low corner frequency is above Nyquist.")
   end

   # create filter
   responsetype = Bandpass(T(freqmin), T(freqmax); fs=fs)
   designmethod = Butterworth(T,corners)
   if zerophase
       A[:] .= filtfilt(digitalfilter(responsetype, designmethod), @view(A[:]))
   else
       A[:] .= filt(digitalfilter(responsetype, designmethod), @view(A[:]))
   end

   return nothing
end
bandpass(A::AbstractArray{<:Union{Float32,Float64},1},freqmin::Float64,
         freqmax::Float64, fs::Float64; corners::Int=4,zerophase::Bool=false) =
         (U = deepcopy(A);bandpass!(U,freqmin,freqmax, fs, corners=corners,
         zerophase=zerophase);return U)

function bandpass!(A::AbstractArray{<:Union{Float32,Float64},2},
                   freqmin::Float64, freqmax::Float64, fs::Float64;
                   corners::Int=4, zerophase::Bool=false)
    fe = 0.5 * fs
    low = freqmin / fe
    high = freqmax / fe
    M,N = size(A)
    T = eltype(A)

    # warn if above Nyquist frequency
    if high - oneunit(high) > -1e-6
        @warn "Selected high corner frequency ($freqmax) of bandpass is at or
        above Nyquist ($fe). Applying a high-pass instead."
        highpass!(A,freqmin,fs,corners=corners,zerophase=zerophase)
        return nothing
    end

    # throw error if low above Nyquist frequency
    if low > 1
        ArgumentError("Selected low corner frequency is above Nyquist.")
    end

    # create filter
    responsetype = Bandpass(T(freqmin), T(freqmax); fs=fs)
    designmethod = Butterworth(T,corners)
    filtx = digitalfilter(responsetype, designmethod)
    if zerophase
        for ii = 1:N
            A[:,ii] .= filtfilt(filtx, @view(A[:,ii]))
        end
    else
        for ii = 1:N
            A[:,ii] .= filt(filtx, @view(A[:,ii]))
        end
    end

    return nothing
end
bandpass(A::AbstractArray{<:Union{Float32,Float64},2},freqmin::Float64,
         freqmax::Float64, fs::Float64; corners::Int=4,zerophase::Bool=false) =
         (U = deepcopy(A);bandpass!(U,freqmin,freqmax,fs,corners=corners,
         zerophase=zerophase);return U)
bandpass!(R::RawData,freqmin::Float64,freqmax::Float64;
          corners::Int=4,zerophase::Bool=false) = (bandpass!(R.x,freqmin,freqmax,
          R.fs,corners=corners,zerophase=zerophase);setfield!(R,:freqmin,freqmin);
          setfield!(R,:freqmax,min(freqmax,R.fs/2));return nothing)
bandpass(R::RawData,freqmin::Float64,freqmax::Float64;
        corners::Int=4,zerophase::Bool=false) = (U = deepcopy(R);bandpass!(U.x,
        freqmin,freqmax,U.fs,corners=corners,zerophase=zerophase);
        setfield!(U,:freqmin,freqmin);
        setfield!(U,:freqmax,min(freqmax,R.fs/2));return U)

 """
     bandstop!(A,freqmin,freqmax,fs,corners=4,zerophase=false)

 Butterworth-Bandstop Filter.

 Filter data `A` removing data between frequencies `freqmin` to `freqmax` using
 `corners` corners.

 # Arguments
 - `A::AbstractArray`: Data to filter
 - `freqmin::Float64`: Stop band low corner frequency.
 - `freqmax::Float64`: Stop band high corner frequency.
 - `fs::Float64`: Sampling rate in Hz.
 - `fs::Int`: Filter corners / order.
 - `zerophase::Bool`: If True, apply filter once forwards and once backwards.
 This results in twice the filter order but zero phase shift in
 the resulting filtered trace.
 """
function bandstop!(A::AbstractArray{<:Union{Float32,Float64},1},
                    freqmin::Float64,freqmax::Float64,fs::Float64;
                    corners::Int=4, zerophase::Bool=false)
    fe = 0.5 * fs
    low = freqmin / fe
    high = freqmax / fe
    T = eltype(A)

    # warn if above Nyquist frequency
    if high > 1
        @warn "Selected high corner frequency ($freqmax) is"
        "above Nyquist ($fe). Setting Nyquist as high corner."
        freqmax = fe
    end

    # throw error if low above Nyquist frequency
    if low > 1
        ArgumentError("Selected low corner frequency is above Nyquist.")
    end

    # create filter
    responsetype = Bandstop(T(freqmin), T(freqmax); fs=fs)
    designmethod = Butterworth(T,corners)
    if zerophase
        A[:] .= filtfilt(digitalfilter(responsetype, designmethod), @view(A[:]))
    else
        A[:] .= filt(digitalfilter(responsetype, designmethod), @view(A[:]))
    end

    return nothing
end
bandstop(A::AbstractArray{<:Union{Float32,Float64},1},freqmin::Float64,
         freqmax::Float64, fs::Float64; corners::Int=4,zerophase::Bool=false) =
         (U = deepcopy(A);bandstop!(U,freqmin,freqmax,corners=corners,
         zerophase=zerophase);return U)

function bandstop!(A::AbstractArray{<:Union{Float32,Float64},2},
                   freqmin::Float64,freqmax::Float64,fs::Float64;
                   corners::Int=4, zerophase::Bool=false)
    fe = 0.5 * fs
    low = freqmin / fe
    high = freqmax / fe
    M,N = size(A)
    T = eltype(A)

    # warn if above Nyquist frequency
    if high > 1
        @warn "Selected high corner frequency ($freqmax) is"
        "above Nyquist ($fe). Setting Nyquist as high corner."
        freqmax = fe
    end

    # throw error if low above Nyquist frequency
    if low > 1
        ArgumentError("Selected low corner frequency is above Nyquist.")
    end

    # create filter
    responsetype = Bandstop(T(freqmin), T(freqmax); fs=fs)
    designmethod = Butterworth(T,corners)
    filtx = digitalfilter(responsetype, designmethod)
    if zerophase
        for ii = 1:N
            A[:,ii] .= filtfilt(filtx, @view(A[:,ii]))
        end
    else
        for ii = 1:N
            A[:,ii] .= filt(filtx, @view(A[:,ii]))
        end
    end

    return nothing
end
bandstop(A::AbstractArray{<:Union{Float32,Float64},2},freqmin::Float64,
         freqmax::Float64, fs::Float64; corners::Int=4,zerophase::Bool=false) =
         (U = deepcopy(A);bandstop!(U,freqmin,freqmax,corners=corners,
         zerophase=zerophase);return U)
bandstop!(R::RawData,freqmin::Float64,freqmax::Float64;
    corners::Int=4,zerophase::Bool=false) = bandstop!(R.x,freqmin,freqmax,
    R.fs,corners=corners,zerophase=zerophase)
bandstop(R::RawData,freqmin::Float64,freqmax::Float64;
  corners::Int=4,zerophase::Bool=false) = (U = deepcopy(R);bandstop!(U.x,
  freqmin,freqmax,U.fs,corners=corners,zerophase=zerophase);return U)

"""
lowpass(A,freq,fs,corners=4,zerophase=false)

Butterworth-Lowpass Filter.

Filter data `A` over certain frequency `freq` using `corners` corners.

# Arguments
- `A::AbstractArray`: Data to filter
- `freq::Float64`: Filter corner frequency.
- `fs::Float64`: Sampling rate in Hz.
- `fs::Int`: Filter corners / order.
- `zerophase::Bool`: If True, apply filter once forwards and once backwards.
This results in twice the filter order but zero phase shift in
the resulting filtered trace.
"""
function lowpass!(A::AbstractArray{<:Union{Float32,Float64},1},freq::Float64,
                  fs::Float64; corners::Int=4, zerophase::Bool=false)
    fe = 0.5 * fs
    f = freq / fe
    T = eltype(A)

    # warn if above Nyquist frequency
    if f >= 1
        @warn """Selected corner frequency ($freq) is
        above Nyquist ($fe). Setting Nyquist as high corner."""
        freq = fe - 1. / fs
    end

    # create filter
    responsetype = Lowpass(T(freq); fs=fs)
    designmethod = Butterworth(T,corners)
    if zerophase
        A[:] .= filtfilt(digitalfilter(responsetype, designmethod), @view(A[:]))
    else
        A[:] .= filt(digitalfilter(responsetype, designmethod), @view(A[:]))
    end
    return nothing
end
lowpass(A::AbstractArray{<:Union{Float32,Float64},1},freq::Float64, fs::Float64;
        corners::Int=4,zerophase::Bool=false) = (U = deepcopy(A);
        lowpass!(U,freq,fs,corners=corners,zerophase=zerophase);return U)

function lowpass!(A::AbstractArray{<:Union{Float32,Float64},2},freq::Float64,
                  fs::Float64; corners::Int=4, zerophase::Bool=false)
    fe = 0.5 * fs
    f = freq / fe
    M,N = size(A)
    T = eltype(A)

    # warn if above Nyquist frequency
    if f >= 1
        @warn """Selected corner frequency ($freq) is
        above Nyquist ($fe). Setting Nyquist as high corner."""
        freq = fe - 1. / fs
    end

    # create filter
    responsetype = Lowpass(T(freq); fs=fs)
    designmethod = Butterworth(T,corners)
    filtx = digitalfilter(responsetype, designmethod)
    if zerophase
        for ii = 1:N
            A[:,ii] .= filtfilt(filtx, @view(A[:,ii]))
        end
    else
        for ii = 1:N
            A[:,ii] .= filt(filtx, @view(A[:,ii]))
        end
    end
    return nothing
end
lowpass(A::AbstractArray{<:Union{Float32,Float64},2},freq::Float64, fs::Float64;
        corners::Int=4,zerophase::Bool=false) = (U = deepcopy(A);
        lowpass!(U,freq,fs,corners=corners,zerophase=zerophase);return U)
lowpass!(R::RawData,freq::Float64; corners::Int=4,
         zerophase::Bool=false) = (lowpass!(R.x,freq,R.fs,corners=corners,
         zerophase=zerophase);setfield!(R,:freqmax,min(freqmax,R.fs/2));
         return nothing)
lowpass(R::RawData,freq::Float64; corners::Int=4,
         zerophase::Bool=false) = (U = deepcopy(R);lowpass!(U.x,freq,U.fs,
         corners=corners,zerophase=zerophase);
         setfield!(R,:freqmax,min(freqmax,R.fs/2));return U)

"""
    highpass(A,freq,fs,corners=4,zerophase=false)

Butterworth-Highpass Filter.

Filter data `A` removing data below certain frequency `freq` using `corners` corners.

# Arguments
- `A::AbstractArray`: Data to filter
- `freq::Float64`: Filter corner frequency.
- `fs::Float64`: Sampling rate in Hz.
- `fs::Int`: Filter corners / order.
- `zerophase::Bool`: If True, apply filter once forwards and once backwards.
This results in twice the filter order but zero phase shift in
the resulting filtered trace.
"""
function highpass!(A::AbstractArray{<:Union{Float32,Float64},1},freq::Float64,
                   fs::Float64; corners::Int=4, zerophase::Bool=false)
    fe = 0.5 * fs
    f = freq / fe
    T = eltype(A)

    # warn if above Nyquist frequency
    if f > 1
        ArgumentError("Selected low corner frequency is above Nyquist.")
    end

    # create filter
    responsetype = Highpass(T(freq); fs=fs)
    designmethod = Butterworth(T,corners)
    if zerophase
        A[:] .= filtfilt(digitalfilter(responsetype, designmethod), @view(A[:]))
    else
        A[:] .= filt(digitalfilter(responsetype, designmethod), @view(A[:]))
    end
    return nothing
end
highpass(A::AbstractArray{<:Union{Float32,Float64},1},freq::Float64,fs::Float64;
         corners::Int=4,zerophase::Bool=false) = (U = deepcopy(A);
         highpass!(U,freq,fs,corners=corners,zerophase=zerophase);return U)

function highpass!(A::AbstractArray{<:Union{Float32,Float64},2},freq::Float64,
        fs::Float64; corners::Int=4, zerophase::Bool=false)
    fe = 0.5 * fs
    f = freq / fe
    M,N = size(A)
    T = eltype(A)

    # warn if above Nyquist frequency
    if f > 1
        ArgumentError("Selected low corner frequency is above Nyquist.")
    end

    # create filter
    responsetype = Highpass(T(freq); fs=fs)
    designmethod = Butterworth(T,corners)
    filtx = digitalfilter(responsetype, designmethod)
    if zerophase
        for ii = 1:N
            A[:,ii] .= filtfilt(filtx, @view(A[:,ii]))
        end
    else
        for ii = 1:N
            A[:,ii] .= filt(filtx, @view(A[:,ii]))
        end
    end
    return nothing
end
highpass(A::AbstractArray{<:Union{Float32,Float64},2},freq::Float64,fs::Float64;
corners::Int=4,zerophase::Bool=false) = (U = deepcopy(A);
highpass!(U,freq,fs,corners=corners,zerophase=zerophase);return U)
highpass!(R::RawData,freq::Float64; corners::Int=4,
         zerophase::Bool=false) = (highpass!(R.x,freq,R.fs,corners=corners,
         zerophase=zerophase);setfield!(R,:freqmin,freqmin);return nothing)
highpass(R::RawData,freq::Float64; corners::Int=4,
         zerophase::Bool=false) = (U = deepcopy(R);highpass!(U.x,freq,U.fs,
         corners=corners,zerophase=zerophase);setfield!(R,:freqmin,freqmin);
         return U)

function hanningwindow(::Type{T},n::Integer; padding::Integer=0, zerophase::Bool=false) where {T<:Real}
    if n < 0
        throw(ArgumentError("`n` must be nonnegative"))
    end
    if padding < 0
        throw(ArgumentError("`padding` must be nonnegative"))
    end
    win = zeros(T,n+padding)
    if n == 1
        win[1] = 0.5*(1+cos(2 * T(pi) *T(0.)))
    elseif zerophase
        # note that the endpoint of the window gets set in both lines. In the
        # unpadded case this will set the same index (which shouldn't make a
        # difference if the window is symmetric), but it's necessary for when
        # there's padding, which ends up in the center of the vector length
        # n÷2+1
        win[1:n÷2+1] .= 0.5 .* (1 .+ cos.(2 * T(pi) .* (range(T(0.0), stop=T(n÷2)/n, length=n÷2+1))))
        # length n÷2
        win[end-n÷2+1:end] .= 0.5 .* (1 .+ cos.(2 * T(pi) *(range(-T(n÷2)/n, stop=-1/T(n), length=n÷2))))
    else
        win[1:n] = 0.5 .*(1 .+ cos.(2 * T(pi) .* (range(-T(0.5), stop=T(0.5), length=n))))
    end
        win
end
hanningwindow(n;padding::Integer=0, zerophase::Bool=false) =
              hanningwindow(Float64,n,padding=padding,zerophase=zerophase)
