using AtomicLevels: CSF, orbital_from_string
using HalfIntegers

angularmomentum(o::RelativisticOrbital) = AtomicLevels.kappa_to_j(o.κ)
angularmomentum(csf::CSF{O,<:HalfInteger}) where O = last(csf.terms)

# Relativistic CSLs and parsing of GRASP CSL files

function parse_rcsf(filename)
    open(filename, "r") do io
        # First line should be "Core subshells:"
        line = readline(io); @assert strip(line) == "Core subshells:"
        line_cores = strip(readline(io), ['\n', '\r'])
        line = readline(io); @assert strip(line) == "Peel subshells:"
        line_peels = readline(io)
        line = readline(io); @assert strip(line) == "CSF(s):"

        core_orbitals = parse_cores(line_cores)
        core_couplings = zeros(HalfInt, length(core_orbitals))
        core_occupations = map(degeneracy, core_orbitals)

        blockid, csfid = 1, 1
        csfs = CSF{RelativisticOrbital{Int},HalfInt}[]
        while ! eof(io)
            line1 = readline(io)
            if startswith(line1, " *")
                blockid += 1
                csfid = 1
                line1 = readline(io)
            end
            line1 = strip(line1, ['\n', '\r'])
            line2 = strip(readline(io), ['\n', '\r'])
            line3 = strip(readline(io), ['\n', '\r'])

            orbitals, noccupations, orbcouplings, csfcouplings = parse_csflines(line1, line2, line3)

            @assert !any(isequal(0), noccupations) # we should never get 0-electron orbitals

            # Fix orbcouplings that are not explicitly written in the CSL file (represented
            # with nothings in the array). It is assumed that this is the case only if the
            # orbital is fully occupied.
            #
            # NOTE: we could, though, also omit values if there is only 1 electron or
            # maxelectrons(orb) - 1 electrons, this which case the angular momentum can
            # only have only one value too.
            for i = 1:length(orbitals)
                orbital, nelec = orbitals[i], noccupations[i]
                if orbcouplings[i] === nothing
                    nelec == degeneracy(orbital) || error("""
                    Unable to fix missing orbital coupling.
                      Orbital $i, orbital=$(repr(orbital)), nelec=$nelec
                    1: $(line1)
                    2: $(line2)
                    3: $(line3)
                    """)
                    orbcouplings[i] = 0
                elseif (nelec == 1 || nelec == degeneracy(orbital) - 1) && orbcouplings[i] != angularmomentum(orbital)
                    @warn "Bad orbital coupling" orbcouplings[i] nelec angularmomentum(orbital)
                elseif orbcouplings[i] > nelec * angularmomentum(orbital)
                    # If the orbital coupling is larger than (# particles) * (l of orbital),
                    # then that has to be an error.
                    @warn "Bad orbital coupling" orbcouplings[i] nelec angularmomentum(orbital)
                end
            end

            # Fix csfcouplings which are not explicitly written to the CSL file. This appears
            # to be the case for "trivial" zero couplings, if the previous CSF layer and
            # current orbital are both zeros.
            for i = 1:length(orbitals)
                oj = orbcouplings[i]
                cj = (i > 1) ? csfcouplings[i-1] : zero(HalfInt)
                Δupper, Δlower = oj+cj, abs(oj-cj)
                if csfcouplings[i] === nothing
                    Δupper == Δlower || error("""
                    Unable to fix missing CSF coupling.
                      Orbital $i, orbital=$(repr(orbitals[i])), oj=$(repr(oj)), cj=$(repr(cj))
                    1: $(line1)
                    2: $(line2)
                    3: $(line3)
                    """)
                    csfcouplings[i] = Δlower
                elseif !(Δlower <= csfcouplings[i] <= Δupper)
                    @warn "Invalid csfcoupling value?" csfcouplings[i] Δupper Δlower
                end
            end

            config = Configuration(vcat(core_orbitals, orbitals), vcat(core_occupations, noccupations), sorted=true)
            subshell_terms = map(x -> convert(Rational{Int}, x),
                vcat(core_couplings, Vector{HalfInt}(orbcouplings)))
            terms = map(x -> convert(Rational{Int}, x),
                vcat(core_couplings, Vector{HalfInt}(csfcouplings)))
            csf = CSF(config, subshell_terms, terms)
            push!(csfs, csf)
        end
        return csfs
    end
end

function parse_csflines(line1, line2, line3)
    # Assuming that the CSF line consists of NNNLL(EE) blocks, each 9 characters long.
    @assert length(line1) % 9 == 0

    orbs = RelativisticOrbital{Int}[]
    orbs_nelectrons = Int[]
    orbs_orbcouplings = Union{HalfInt,Nothing}[]
    orbs_csfcouplings = Union{HalfInt,Nothing}[]
    norbitals = div(length(line1), 9) # number of orbitals in this group
    for i = 1:norbitals
        orb = line1[9*(i-1)+1:9*i]
        @assert orb[6]=='(' && orb[9]==')'
        orbital = orbital_from_string(RelativisticOrbital, strip(orb[1:5]))
        # n = parse(Int, orb[1:3])
        # kappa = parse_j(orb[4:5])
        nelec = parse(Int, orb[7:8])

        # pick out coupled angular momentum from the second line:
        angmom =  if length(line2) < 9*i
            nothing
        else
            parse_angmom_string(line2[9*(i-1)+1:9*i])
        end

        # Pick the J-coupling from between the orbitals (line3).
        # The items in that line are shifted by three characters to the right for
        # some reason.. except for the last one, which defines the J^P values of
        # the CSF. That one is shifted by 1 character.. and then one after that
        # is the parity +/- symbol.
        c2J_idx_first, c2J_idx_last = if i < norbitals
            # So, for the non-last ones we assume a 9 character block that has been
            # shifted by 3 characters to the right.
            # +1 to go from 0-based to 1-based
            9*(i-1)+3+1, 9*i+3
        else # i == norbitals -- the last non-regular coupling
            9*(i-1)+3+1, 9*i+1
        end
        c2J_string = line3[c2J_idx_first:c2J_idx_last]
        coupled_angmom = try
            parse_angmom_string(c2J_string)
        catch e
            error("""
            Error parsing 2J value on line 3 (i=$i)
              range $(c2J_idx_first):$(c2J_idx_last) -> '$(c2J_string)'
            1: $(line1)
            2: $(line2)
            3: $(line3)
            $(' '^(c2J_idx_first+2))^$('-'^(c2J_idx_last-c2J_idx_first-1))^
            """)
        end
        push!(orbs_csfcouplings, coupled_angmom)

        push!(orbs, orbital)
        push!(orbs_nelectrons, nelec)
        push!(orbs_orbcouplings, angmom)
    end
    @assert length(orbs_csfcouplings) == norbitals

    return orbs, orbs_nelectrons, orbs_orbcouplings, orbs_csfcouplings
end

function parse_angmom_string(s)
    length(strip(s)) == 0 && return nothing
    parse(HalfInt, s)
end

function parse_cores(line)
    orbstrings = split(line)
    orbs = RelativisticOrbital{Int}[]
    for os in orbstrings
        push!(orbs, orbital_from_string(RelativisticOrbital, strip(os)))
    end
    orbs
end
