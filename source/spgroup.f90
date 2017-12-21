! FDMNES subroutines

! Program giving all the atoms of the mesh from the non equivalent atoms and from the space group.
! A big part comes from Ch. Brouder.

! Space_Group Name of the symmetry group
! NMAXOP      Maximum number of symmetry operations

subroutine spgroup(Cif,Cif_file,Do_exp,neq,ngroup,ngroup_neq,itype,posn,posout,Space_group)

  use declarations
  implicit none

  integer, parameter:: nmaxop = 192

  integer:: i, ia, is, j, ja, js, k, ks, ngroup, ngroup_neq, nsym
  
  character(len=1):: SGTrans
  character(len=13):: Space_Group
  character(len=132):: Cif_file

  integer, dimension(ngroup):: itype
  integer, dimension(ngroup_neq):: neq
  integer, dimension(:), allocatable:: itypeq

  logical:: Check, Cif, Do_exp

  real(kind=db):: eps
  real(kind=db), dimension(3):: Along_XY, Along_YZ, Along_XZ, Along_XYZ, q
  real(kind=db), dimension(3,3,nmaxop):: Mat
  real(kind=db), dimension(3,nmaxop):: Trans
  real(kind=db), dimension(3,ngroup_neq):: posn
  real(kind=db), dimension(3,ngroup):: posout
  real(kind=db), dimension(:,:), allocatable:: qq

  Along_XY(1) = 1._db; Along_XY(2) = 1._db; Along_XY(3) = 0._db;
  Along_YZ(1) = 0._db; Along_YZ(2) = 1._db; Along_YZ(3) = 1._db;
  Along_XZ(1) = 1._db; Along_XZ(2) = 0._db; Along_XZ(3) = 1._db;
  Along_XYZ(1) = 1._db; Along_XYZ(2) = 1._db; Along_XYZ(3) = 1._db;

  Mat(:,:,:) = 0._db
  Trans(:,:) = 0._db
  Check = .false.

  call symgrp(Cif,Cif_file,Space_Group,Mat,Trans,nsym,nmaxop,SGTrans)

  select case(SGTrans)

    case('A')

      do is = 1,nsym
        js = is + nsym
        Mat(:,:,js) = Mat(:,:,is)
        Trans(:,js) = Trans(:,is) + 0.5_db * Along_YZ(:)
      end do
      nsym = 2 * nsym

    case('B')

      do is = 1,nsym
        js = is + nsym
        Mat(:,:,js) = Mat(:,:,is)
        Trans(:,js) = Trans(:,is) + 0.5_db * Along_XZ(:)
      end do
      nsym = 2 * nsym

    case('C')

      do is = 1,nsym
        js = is + nsym
        Mat(:,:,js) = Mat(:,:,is)
        Trans(:,js) = Trans(:,is) + 0.5_db * Along_XY(:)
      end do
      nsym = 2 * nsym

    case('F')

      do is = 1,nsym
        do k = 2,4
          js = is + ( k - 1 ) * nsym
          Mat(:,:,js) = Mat(:,:,is)
          select case(k)
            Case(2)
              Trans(:,js) = Trans(:,is) + 0.5_db * Along_YZ(:)
            Case(3)
              Trans(:,js) = Trans(:,is) + 0.5_db * Along_XZ(:)
            Case(4)
              Trans(:,js) = Trans(:,is) + 0.5_db * Along_XY(:)
          end select
        end do
      end do
      nsym = 4 * nsym

    case('I')

      do is = 1,nsym
        js = is + nsym
        Mat(:,:,js) = Mat(:,:,is)
        Trans(:,js) = Trans(:,is) + 0.5_db * Along_XYZ(:)
      end do
      nsym = 2 * nsym

    case('H')

      do is = 1,nsym
        do k = 2,3
          js = is + ( k - 1 ) * nsym
          Mat(:,:,js) = Mat(:,:,is)
          Trans(:,js) = Trans(:,is)
          select case(k)
            Case(2)
              Trans(1,js) = Trans(1,js) + 2._db / 3
              Trans(2:3,js) = Trans(2:3,js) + 1._db / 3
            Case(3)
              Trans(1,js) = Trans(1,js) + 1._db / 3
              Trans(2:3,js) = Trans(2:3,js) + 2._db / 3
          end select
        end do
      end do
      nsym = 3 * nsym

  end select

  if( check ) then
    write(3,'(/A)') '        Matrix           Trans'
    do is = 1,nsym
      write(3,'(A,i3)') '  is =', is
      do i = 1,3
        write(3,'(3f7.3,3x,f7.3)') Mat(i,:,is), Trans(i,is)
      end do
    end do
  endif

  eps = 0.0000001_db
  do j = 1,2
    where( posn > 1._db - eps ) posn = posn - 1
    where( posn < - eps ) posn = posn + 1
  end do

  allocate( qq(3,nmaxop*ngroup_neq) )
  allocate( itypeq(nmaxop*ngroup_neq) )

  js = 0
  do ia = 1,ngroup_neq
    ja = 0
    boucle_is: do is = 1,nsym
      do i = 1,3
        q(i) = sum( Mat(i,:,is) * posn(:,ia) ) + Trans(i,is)
      end do
      do j = 1,2
        where( q > 1._db - eps ) q = q - 1
        where( q < - eps ) q = q + 1
      end do
      do ks = 1,js
        if( sum( abs(qq(:,ks)-q(:)) ) < 0.000001_db .and. itypeq(ks) == itype(ia) ) cycle boucle_is
      end do
      js = js + 1
      ja = ja + 1
      qq(:,js) = q(:)
      itypeq(js) = itype(ia)
      if( Do_exp ) posout(:,js ) = qq(:,js)
    end do boucle_is
    if( Do_exp ) neq(ia) = ja
  end do

  deallocate( itypeq, qq )
  if( .not. Do_exp ) ngroup = js

  return
end

!*********************************************************************

subroutine symgrp(Cif,Cif_file,Space_Group,Mat,Trans,nbsyop,nmaxop,SGTrans)

! This subroutine looks for the space group whose name is in Space_Group.
! If it is found, it outputs the number of symmetry operations, and builds the matrices for these operations.

! Variable description :
!   Space_Group Name of the symmetry group
!   NBSYOP      Number of symmetry operations
!   NMAXOP      Maximum number of symmetry operations
!   sgnb        Space group number

  use declarations
  implicit none

  integer:: nmaxop

  character(len=1):: SGTrans
  character(len=10):: sgnbcar, sgnbcar0
  character(len=13):: sgschoenfliess, Space_Group
  character(len=27):: sgHMshort, sgHMlong
  character(len=80):: line, mot, motb
  character(len=132):: Cif_file
  character(len=80), dimension(nmaxop):: lines

  character(len=80), dimension(5527):: spacegroupdata
  common /spacegroupdata/ spacegroupdata

  integer:: i, i1, i2, ipr, istat, itape, j, k, l, nbsyop, sgnb, currentLineNum

  logical:: Cif, pareil

  real(kind=db), dimension(3,3,nmaxop):: Mat
  real(kind=db), dimension(3,nmaxop):: Trans
  real(kind=db), dimension(3,4):: Matrix(3,4)

  pareil = .false.

  if( Cif ) then
    itape = 7

    Open(itape, file = Cif_file, status='old', iostat=istat)
    if( istat /= 0 ) call write_open_error(Cif_file,istat,1)

    do
     read(itape,'(A)') mot
     if( mot(1:26) == '_symmetry_equiv_pos_as_xyz' .or. mot(1:32) == '_space_group_symop_operation_xyz' ) exit 
    end do
    
    boucle_i: do i = 1,1000

      read(itape,'(A)' ) mot
      line = ' '
      
      do j = 1,80
        if( mot(j:j) == ',' ) exit
      end do
      if( j > 80 ) exit boucle_i

      boucle_j: do j = 1,80
        if( mot(j:j) == "'" ) then
          do k = 1,j
            mot(k:k) = ' '
          end do
          do k = j+1,80
            if( mot(k:k) == "'" ) then
              mot(k:k) = ' '
              exit boucle_j
            endif
          end do
        endif 
      end do boucle_j

      do k = 1,2
        motb = adjustl( mot )
        l = len_trim( motb )
        do j = 1,l-1
          if( motb(j:j) /= ' ' ) cycle
          mot = ' '
          mot(1:j-1) = motb(1:j-1)
          mot(j:l-1) = motb(j+1:l)  
        end do
      end do
      
      lines(i) = adjustl(mot)
        
    end do boucle_i
    
    nbsyop = i - 1

    SGTrans = ' ' ! Space_group(1:1)

    Close(itape)
  else
  
! Ask for exact definition of space group.
! sgnbcar0 is the detailed number of the spacegroup, specifying axis and origin conventions

    call locateSG(Space_Group,sgnbcar0)

! In spacegroupdata the name of the symmetry group follows a *<space> look for it.
! If a * is found, check that the following string is the name of the desired symmetry group.

    do i = 1,5527

      line = spacegroupdata(i)
      if (line(1:1) /= '*') cycle

! Analyse the line giving space group name(s)
      call analysename(line,sgnb,sgnbcar,sgschoenfliess,sgHMshort,sgHMlong)
      Pareil = sgnbcar == sgnbcar0
      SGTrans = sgHMlong(1:1)
      if( index(sgHMlong,'H') /= 0 ) SGTrans = 'H'
      if( pareil ) exit

    end do
    currentLineNum = i
! Look for nbsyop
    do i = 1,1000
      line = spacegroupdata(currentLineNum+i)
      if( line(1:1) == '*' .or. line(1:1) == ' ' ) exit
      lines(i) = line
      if( currentLineNum+i >= 5527 ) exit
    end do
    nbsyop = i - 1

    if( index(sgnbcar,'R') /= 0 ) then
      call write_error
      do ipr = 6,9,3
        write(ipr,110)
      end do
      stop
    end if

  endif
   
! Read the NBSYOP symmetry operations, and build the corresponding transformation matrix.

  do i = 1,nbsyop
    call findop(lines(i),Matrix)
    do i1=1,3
      do i2=1,3
        Mat(i1,i2,i) = Matrix(i1,i2)
      end do
      Trans(i1,i) = Matrix(i1,4)
    end do
  end do

  return
  100 format(//' Space group name, ',a13,', not found in the file ',A//)
  110 format(//' Rhombohedral axes are not implemented ! Please, convert to hexagonal axes'//)
end

!***********************************************************************

subroutine findop(line,matrix)

! This subroutine takes the line LINE coming from spacegroupdata
! and builds the matrix corresponding to the symmetry operation written in the line.
! The symmetry operation is written in the line as e.g. -y,x,-z

!   line    Line red from the input file
!   Matrix  Matrix of the symmetry operation (output) in the crystal axes

  use declarations
  implicit none

  character(len=80) line

  integer i, j, ibegin, iend, ifin, ipr, ncar

  real(kind=db), dimension(3,4):: matrix

! Initialize Matrix
  do i=1,3
    do j=1,4
      Matrix(i,j) = 0._db
    end do
  end do
  ibegin = 1
  iend = len_trim(line)

! The symmetry operation is written as a line of 3 words
! separated by commas e.g. -y,x,-z
!   NCAR is the number of characters in each word
!   IBEGIN the place of the beginning of the word
!   IFIN   the place of the end of the word
!   IEND   the place of the end of the line

  do i = 1,3

    ncar = Index(line(ibegin:iend),',') - 1
    ifin = ibegin + ncar - 1
    if( ncar == -1 ) ifin = iend

    select case( line(ibegin:ifin) )

      case('x','+x')
        Matrix(i,1) = 1._db

      case('-x')
        Matrix(i,1) = -1._db

      case('y','+y')
        Matrix(i,2) = 1._db

      case('-y')
        Matrix(i,2) = -1._db

      case('z','+z')
        Matrix(i,3) = 1._db

      case('-z')
        Matrix(i,3) = -1._db

      case('x-y','+x-y','-y+x')
        Matrix(i,1) = 1._db
        Matrix(i,2) = -1._db

      case('y-x','+y-x','-x+y')
        Matrix(i,1) = -1._db
        Matrix(i,2) = 1._db

      case('1/2+x','x+1/2')
        Matrix(i,1) = 1._db
        Matrix(i,4) = 0.5_db

      case('x-1/2','+x-1/2','-1/2+x')
        Matrix(i,1) = 1._db
        Matrix(i,4) = -0.5_db

      case('1/2-x','-x+1/2')
        Matrix(i,1) = -1._db
        Matrix(i,4) = 0.5_db

      case('-1/2-x','-x-1/2')
        Matrix(i,1) = -1._db
        Matrix(i,4) = -0.5_db

      case('1/2+y','y+1/2','+y+1/2')
        Matrix(i,2) = 1._db
        Matrix(i,4) = 0.5_db

      case('1/2-y','-y+1/2')
        Matrix(i,2) = -1._db
        Matrix(i,4) = 0.5_db

      case('-1/2+y','y-1/2','+y-1/2')
        Matrix(i,2) =  1._db
        Matrix(i,4) = -0.5_db

      case('-y-1/2','-1/2-y')
        Matrix(i,2) = -1._db
        Matrix(i,4) = -0.5_db

      case('z+1/2','+z+1/2','1/2+z')
        Matrix(i,3) = 1._db
        Matrix(i,4) = 0.5_db

      case('1/2-z','-z+1/2')
        Matrix(i,3) = -1._db
        Matrix(i,4) = 0.5_db

      case('-1/2+z','z-1/2','+z-1/2')
        Matrix(i,3) = 1._db
        Matrix(i,4) = -0.5_db

      case('-z-1/2','-1/2-z')
        Matrix(i,3) = -1._db
        Matrix(i,4) = -0.5_db

      case('1/4+x','x+1/4','+x+1/4')
        Matrix(i,1) = 1._db
        Matrix(i,4) = 0.25_db

      case('1/4-x','-x+1/4')
        Matrix(i,1) = -1._db
        Matrix(i,4) = 0.25_db

      case('1/4+y','y+1/4','+y+1/4')
        Matrix(i,2) = 1._db
        Matrix(i,4) = 0.25_db

      case('1/4-y','-y+1/4')
        Matrix(i,2) = -1._db
        Matrix(i,4) = 0.25_db

      case('1/4+z','z+1/4','+z+1/4')
        Matrix(i,3) = 1._db
        Matrix(i,4) = 0.25_db

      case('1/4-z','-z+1/4')
        Matrix(i,3) = -1._db
        Matrix(i,4) = 0.25_db

      case('3/4+x','x+3/4','+x+3/4')
        Matrix(i,1) = 1._db
        Matrix(i,4) = 0.75_db

      case('3/4-x','-x+3/4')
        Matrix(i,1) = -1._db
        Matrix(i,4) = 0.75_db

      case('3/4+y','y+3/4','+y+3/4')
        Matrix(i,2) = 1._db
        Matrix(i,4) = 0.75_db

      case('3/4-y','-y+3/4')
        Matrix(i,2) = -1._db
        Matrix(i,4) = 0.75_db

      case('3/4+z','z+3/4','+z+3/4')
        Matrix(i,3) = 1._db
        Matrix(i,4) = 0.75_db

      case('3/4-z','-z+3/4')
        Matrix(i,3) = -1._db
        Matrix(i,4) = 0.75_db

      case('z+1/6','+z+1/6','1/6+z')
        Matrix(i,3) = 1._db
        Matrix(i,4) = 1/6._db

      case('z+1/3','+z+1/3','1/3+z')
        Matrix(i,3) = 1._db
        Matrix(i,4) = 1/3._db

      case('-z+1/3','1/3-z')
        Matrix(i,3) = -1._db
        Matrix(i,4) = 1/3._db

      case('z+2/3','+z+2/3','2/3+z')
        Matrix(i,3) = 1._db
        Matrix(i,4) = 2/3._db

      case('-z+2/3','2/3-z')
        Matrix(i,3) = -1._db
        Matrix(i,4) = 2/3._db

      case('z+5/6','+z+5/6','5/6+z')
        Matrix(i,3) = 1.
        Matrix(i,4) = 5/6._db

      case('x+1/3','+x+1/3','1/3+x')
        Matrix(i,1) = 1._db
        Matrix(i,4) = 1/3._db

      case('x+2/3','+x+2/3','2/3+x')
        Matrix(i,1) = 1._db
        Matrix(i,4) = 2/3._db

      case('-x+1/3','1/3-x')
        Matrix(i,1) = -1._db
        Matrix(i,4) = 1/3._db

      case('-x+2/3','2/3-x')
        Matrix(i,1) = -1._db
        Matrix(i,4) = 2/3._db

      case('y+1/3','+y+1/3','1/3+y')
        Matrix(i,2) = 1._db
        Matrix(i,4) = 1/3._db

      case('y+2/3','+y+2/3','2/3+y')
        Matrix(i,2) = 1._db
        Matrix(i,4) = 2/3._db

      case('-y+1/3','1/3-y')
        Matrix(i,2) = -1._db
        Matrix(i,4) = 1/3._db

      case('-y+2/3','2/3-y')
        Matrix(i,2) = -1._db
        Matrix(i,4) = 2/3._db

      case('x-y+1/3','+x-y+1/3','-y+x+1/3','1/3+x-y')
        Matrix(i,1) = 1._db
        Matrix(i,2) = -1._db
        Matrix(i,4) = 1/3._db

      case('x-y+2/3','+x-y+2/3','-y+x+2/3','2/3+x-y')
        Matrix(i,1) = 1._db
        Matrix(i,2) = -1._db
        Matrix(i,4) = 2/3._db

      case('-x+y+1/3','y-x+1/3','+y-x+1/3','1/3-x+y')
        Matrix(i,1) = -1._db
        Matrix(i,2) = 1._db
        Matrix(i,4) = 1/3._db

      case('-x+y+2/3','y-x+2/3','+y-x+2/3','2/3-x+y')
        Matrix(i,1) = -1._db
        Matrix(i,2) = 1._db
        Matrix(i,4) = 2/3._db

      case default
        call write_error
        do ipr = 6,9,3
          write(ipr,100) line
        end do
        stop

    end select

    ibegin = ifin + 2

  end do

  return
  100 format(//' Sorry, an operation is not known in the line',/, &
      1x,A,/,' Please add it to subroutine Findop in spgroup.f'/)
end

!***********************************************************************

subroutine analysename(line,sgnb,sgnbcar,sgschoenfliess,sgHMshort,sgHMlong)

! This program analyses the line containing various names of a space group. 
! This line was generated with the space group program SGinfo

!  line       Line of data
!  sgnb       Space group number
!  sgnbcar    Space group number (and eventually axis choice
!             or origin choice) in characters
!  sgschoenfliess Space group name in Schoenfliess notation
!  sgHMshort  Space group name in Hermann-Mauguin short notation
!  sgHMlong   Space group name in Hermann-Mauguin long notation

  use declarations
  implicit none

  character(len=10):: sgnbcar
  character(len=13):: sgschoenfliess
  character(len=80):: line
  character(len=27):: sgHMshort,sgHMlong

  integer sgnb,i0,i

!   Read space group number
  read(line,'(1x,i3)') sgnb
  read(line,'(1x,a10)') sgnbcar
  read(line,'(12x,a13)') sgschoenfliess
  read(line,'(26x,a26)') sgHMshort

!    Find Hermann-Mauguin long name
  i0 = index(sgHMshort,'=')
  if(i0.eq.0) then
    sgHMlong = sgHMshort
  else
    do i = i0+2,26
      sgHMlong(i-i0-1:i-i0-1) = sgHMshort(i:i)
    end do
    do i = 26-i0,26
      sgHMlong(i:i) = ' '
    end do
    do i = i0,26
      sgHMshort(i:i) = ' '
    end do
  end if

!    For Hermann-Mauguin short name, strip additional characters
  i0 = index(sgHMshort,':')
  if(i0.ne.0) then
    do i = i0,len(sgHMshort)
      sgHMshort(i:i) = ' '
    end do
  end if

  return
end

!***********************************************************************

subroutine locateSG(Space_Group,sgnbcar0)

!    This program locates all space groups whose names
!    look like Space_Group and asks to choose the right one
!  line       Line of data
!  sgnb       Space group number
!  sgnbcar    Space group number (and eventually axis choice or origin choice) in characters
!  sgschoenfliess Space group name in Schoenfliess notation
!  sgHMshort  Space group name in Hermann-Mauguin short notation
!  sgHMlong   Space group name in Hermann-Mauguin long notation

  use declarations
  implicit none

  character(len=80), dimension(5527):: spacegroupdata
  common /spacegroupdata/ spacegroupdata

  character(len=10) sgnbcar, sgnbcar0, sgnbcar1
  character(len=13) sgHMlong13, sgHMshort13, sgnbcar13, sgschoenfliess, sgschoenfliess1, Space_Group
  character(len=27) sgHMshort, sgHMshort1, sgHMlong, sgHMlong1
  character(len=80) line

  integer i, ipr, sgnb, sgnb1, nbsol

  logical pareil

  nbsol = 0

  do i = 1,5527

    line = spacegroupdata(i)
    if( line(1:1) /= '*' ) cycle

    call analysename(line,sgnb,sgnbcar,sgschoenfliess,sgHMshort,sgHMlong)

    sgHMlong = Adjustl( sgHMlong )
    sgHMlong13(1:13) = sgHMlong(1:13)
    sgHMshort = Adjustl( sgHMshort )
    sgHMshort13(1:13) = sgHMshort(1:13)
    sgnbcar13 = ' '
    sgnbcar13(1:10) = sgnbcar(1:10)
    sgnbcar13 = Adjustl( sgnbcar13 )

    Pareil = ( sgnbcar13 == Space_group ) .or. ( sgschoenfliess == Space_group ) .or. ( sgHMshort13 == Space_group ) &
           .or. ( sgHMlong13 == Space_group )

    if( pareil ) then
      nbsol = nbsol + 1
      sgnbcar0 = sgnbcar
      if( nbsol == 2 ) then
        call write_error
        do ipr = 6,9,3
          write(ipr,110) Space_Group
          write(ipr,120)
          write(ipr,130) sgnb1, sgnbcar1, sgschoenfliess1, sgHMshort1, sgHMlong1
        end do
      end if
      if( nbsol == 1 ) then
        sgnb1 = sgnb; sgnbcar1 = sgnbcar
        sgschoenfliess1 = sgschoenfliess
        sgHMshort1 = sgHMshort
        sgHMlong1 = sgHMlong
      else
        do ipr = 6,9,3
          write(ipr,130) sgnb, sgnbcar, sgschoenfliess, sgHMshort, sgHMlong
        end do
      endif
    end if

  end do

  return
  110 format(/' Space group is ',a13)
  120 format(/' Nb  Full Nb', ' Schoenfliess Hermann-Mauguin Long Hermann-Mauguin')
  130 format(i3,2x,a11,1x,a10,3x,a10,9x,a10)
  140 format(/'   There are more than one definition of the', ' group operations !',/, &
    ' Please enter the full number (Full Nb in the above list)',/ ' of the set of operations that you desire.',/ &
    ' See the International Tables or the file ',a10,' for more', ' detail.'/)
end

!----------------------------------------------------------------------------------------------------------------

! Spacegroup.data
 
! From Ch. Brouder 4-dec-95

!  This is list of all space groups, with all choice of axes and all origins 
!  as defined in the Handbook of Crystallography, Vol.A.
!  For each space group, the first line gives the space group number,
!  the Schoenfliess symbol, the Hermann-Mauguin symbol (short and long),
!  and the Hall symbol (S.R. Hall; Space-Group Notation with an Explicit
!  Origin, Acta Cryst. (1981). A37, 517-525, or International Tables
!  Volume B 1994, Section 1.4. Symmetry in reciprocal space (Sydney R. Hall,
!  Crystallography Centre, University of Western Australia. (syd@crystal.uwa.edu.au).
!  This file was generated automatically using the space group analysis
!  program "sginfo", written by Ralf W. Grosse-Kunstleve, Laboratory of
!  Crystallography, ETH Zurich, Switzerland (ralf@kristall.erdw.ethz.ch).
!  In this list all space group operations are given except for the
!  translations given by the lattice type (R,I,F)
!  Group C-1 added by F. Farges.

block data spacegroupdatasubroutine

  character(len=80), dimension(5527):: spacegroupdata
  common /spacegroupdata/ spacegroupdata

  data spacegroupdata/ &
    '*  1        C1^1          P1                           P 1',&
    'x,y,z',&
    '',&
    '*  2:a      Ci^1          P-1                         -P 1',&
    'x,y,z',&
    '-x,-y,-z',&
    '',&
    '*  2:b      Ci^1          C-1                         -C 1',&
    'x,y,z',&
    '-x,-y,-z',&
    'x+1/2,y+1/2,z',&
    '-x+1/2,-y+1/2,-z',&
    '',&
    '*  3:b      C2^1          P2:b = P121                  P 2y',&
    'x,y,z',&
    '-x,y,-z',&
    '',&
    '*  3:c      C2^1          P2:c = P112                  P 2',&
    'x,y,z',&
    '-x,-y,z',&
    '',&
    '*  3:a      C2^1          P2:a = P211                  P 2x',&
    'x,y,z',&
    'x,-y,-z',&
    '',&
    '*  4:b      C2^2          P21:b = P1211                P 2yb',&
    'x,y,z',&
    '-x,y+1/2,-z',&
    '',&
    '*  4:c      C2^2          P21:c = P1121                P 2c',&
    'x,y,z',&
    '-x,-y,z+1/2',&
    '',&
    '*  4:a      C2^2          P21:a = P2111                P 2xa',&
    'x,y,z',&
    'x+1/2,-y,-z',&
    '',&
    '*  5:b1     C2^3          C2:b1 = C121                 C 2y',&
    'x,y,z',&
    '-x,y,-z',&
    '',&
    '*  5:b2     C2^3          C2:b2 = A121                 A 2y',&
    'x,y,z',&
    '-x,y,-z',&
    '',&
    '*  5:b3     C2^3          C2:b3 = I121                 I 2y',&
    'x,y,z',&
    '-x,y,-z',&
    '',&
    '*  5:c1     C2^3          C2:c1 = A112                 A 2',&
    'x,y,z',&
    '-x,-y,z',&
    '',&
    '*  5:c2     C2^3          C2:c2 = B112                 B 2',&
    'x,y,z',&
    '-x,-y,z',&
    '',&
    '*  5:c3     C2^3          C2:c3 = I112                 I 2',&
    'x,y,z',&
    '-x,-y,z',&
    '',&
    '*  5:a1     C2^3          C2:a1 = B211                 B 2x',&
    'x,y,z',&
    'x,-y,-z',&
    '',&
    '*  5:a2     C2^3          C2:a2 = C211                 C 2x',&
    'x,y,z',&
    'x,-y,-z',&
    '',&
    '*  5:a3     C2^3          C2:a3 = I211                 I 2x',&
    'x,y,z',&
    'x,-y,-z',&
    '',&
    '*  6:b      Cs^1          Pm:b = P1m1                  P -2y',&
    'x,y,z',&
    'x,-y,z',&
    '',&
    '*  6:c      Cs^1          Pm:c = P11m                  P -2',&
    'x,y,z',&
    'x,y,-z',&
    '',&
    '*  6:a      Cs^1          Pm:a = Pm11                  P -2x',&
    'x,y,z',&
    '-x,y,z',&
    '',&
    '*  7:b1     Cs^2          Pc:b1 = P1c1                 P -2yc',&
    'x,y,z',&
    'x,-y,z+1/2',&
    '',&
    '*  7:b2     Cs^2          Pc:b2 = P1n1                 P -2yac',&
    'x,y,z',&
    'x+1/2,-y,z+1/2',&
    '',&
    '*  7:b3     Cs^2          Pc:b3 = P1a1                 P -2ya',&
    'x,y,z',&
    'x+1/2,-y,z',&
    '',&
    '*  7:c1     Cs^2          Pc:c1 = P11a                 P -2a',&
    'x,y,z',&
    'x+1/2,y,-z',&
    '',&
    '*  7:c2     Cs^2          Pc:c2 = P11n                 P -2ab',&
    'x,y,z',&
    'x+1/2,y+1/2,-z',&
    '',&
    '*  7:c3     Cs^2          Pc:c3 = P11b                 P -2b',&
    'x,y,z',&
    'x,y+1/2,-z',&
    '',&
    '*  7:a1     Cs^2          Pc:a1 = Pb11                 P -2xb',&
    'x,y,z',&
    '-x,y+1/2,z',&
    '',&
    '*  7:a2     Cs^2          Pc:a2 = Pn11                 P -2xbc',&
    'x,y,z',&
    '-x,y+1/2,z+1/2',&
    '',&
    '*  7:a3     Cs^2          Pc:a3 = Pc11                 P -2xc',&
    'x,y,z',&
    '-x,y,z+1/2',&
    '',&
    '*  8:b1     Cs^3          Cm:b1 = C1m1                 C -2y',&
    'x,y,z',&
    'x,-y,z',&
    '',&
    '*  8:b2     Cs^3          Cm:b2 = A1m1                 A -2y',&
    'x,y,z',&
    'x,-y,z',&
    '',&
    '*  8:b3     Cs^3          Cm:b3 = I1m1                 I -2y',&
    'x,y,z',&
    'x,-y,z',&
    '',&
    '*  8:c1     Cs^3          Cm:c1 = A11m                 A -2',&
    'x,y,z',&
    'x,y,-z',&
    '',&
    '*  8:c2     Cs^3          Cm:c2 = B11m                 B -2',&
    'x,y,z',&
    'x,y,-z',&
    '',&
    '*  8:c3     Cs^3          Cm:c3 = I11m                 I -2',&
    'x,y,z',&
    'x,y,-z',&
    '',&
    '*  8:a1     Cs^3          Cm:a1 = Bm11                 B -2x',&
    'x,y,z',&
    '-x,y,z',&
    '',&
    '*  8:a2     Cs^3          Cm:a2 = Cm11                 C -2x',&
    'x,y,z',&
    '-x,y,z',&
    '',&
    '*  8:a3     Cs^3          Cm:a3 = Im11                 I -2x',&
    'x,y,z',&
    '-x,y,z',&
    '',&
    '*  9:b1     Cs^4          Cc:b1 = C1c1                 C -2yc',&
    'x,y,z',&
    'x,-y,z+1/2',&
    '',&
    '*  9:b2     Cs^4          Cc:b2 = A1n1                 A -2yac',&
    'x,y,z',&
    'x+1/2,-y,z+1/2',&
    '',&
    '*  9:b3     Cs^4          Cc:b3 = I1a1                 I -2ya',&
    'x,y,z',&
    'x+1/2,-y,z',&
    '',&
    '*  9:-b1    Cs^4          Cc:-b1 = A1a1                A -2ya',&
    'x,y,z',&
    'x+1/2,-y,z',&
    '',&
    '*  9:-b2    Cs^4          Cc:-b2 = C1n1                C -2ybc',&
    'x,y,z',&
    'x,-y+1/2,z+1/2',&
    '',&
    '*  9:-b3    Cs^4          Cc:-b3 = I1c1                I -2yc',&
    'x,y,z',&
    'x,-y,z+1/2',&
    '',&
    '*  9:c1     Cs^4          Cc:c1 = A11a                 A -2a',&
    'x,y,z',&
    'x+1/2,y,-z',&
    '',&
    '*  9:c2     Cs^4          Cc:c2 = B11n                 B -2bc',&
    'x,y,z',&
    'x,y+1/2,-z+1/2',&
    '',&
    '*  9:c3     Cs^4          Cc:c3 = I11b                 I -2b',&
    'x,y,z',&
    'x,y+1/2,-z',&
    '',&
    '*  9:-c1    Cs^4          Cc:-c1 = B11b                B -2b',&
    'x,y,z',&
    'x,y+1/2,-z',&
    '',&
    '*  9:-c2    Cs^4          Cc:-c2 = A11n                A -2ac',&
    'x,y,z',&
    'x+1/2,y,-z+1/2',&
    '',&
    '*  9:-c3    Cs^4          Cc:-c3 = I11a                I -2a',&
    'x,y,z',&
    'x+1/2,y,-z',&
    '',&
    '*  9:a1     Cs^4          Cc:a1 = Bb11                 B -2xb',&
    'x,y,z',&
    '-x,y+1/2,z',&
    '',&
    '*  9:a2     Cs^4          Cc:a2 = Cn11                 C -2xbc',&
    'x,y,z',&
    '-x,y+1/2,z+1/2',&
    '',&
    '*  9:a3     Cs^4          Cc:a3 = Ic11                 I -2xc',&
    'x,y,z',&
    '-x,y,z+1/2',&
    '',&
    '*  9:-a1    Cs^4          Cc:-a1 = Cc11                C -2xc',&
    'x,y,z',&
    '-x,y,z+1/2',&
    '',&
    '*  9:-a2    Cs^4          Cc:-a2 = Bn11                B -2xbc',&
    'x,y,z',&
    '-x,y+1/2,z+1/2',&
    '',&
    '*  9:-a3    Cs^4          Cc:-a3 = Ib11                I -2xb',&
    'x,y,z',&
    '-x,y+1/2,z',&
    '',&
    '* 10:b      C2h^1         P2/m:b = P12/m1             -P 2y',&
    'x,y,z',&
    '-x,y,-z',&
    '-x,-y,-z',&
    'x,-y,z',&
    '',&
    '* 10:c      C2h^1         P2/m:c = P112/m             -P 2',&
    'x,y,z',&
    '-x,-y,z',&
    '-x,-y,-z',&
    'x,y,-z',&
    '',&
    '* 10:a      C2h^1         P2/m:a = P2/m11             -P 2x',&
    'x,y,z',&
    'x,-y,-z',&
    '-x,-y,-z',&
    '-x,y,z',&
    '',&
    '* 11:b      C2h^2         P21/m:b = P121/m1           -P 2yb',&
    'x,y,z',&
    '-x,y+1/2,-z',&
    '-x,-y,-z',&
    'x,-y+1/2,z',&
    '',&
    '* 11:c      C2h^2         P21/m:c = P1121/m           -P 2c',&
    'x,y,z',&
    '-x,-y,z+1/2',&
    '-x,-y,-z',&
    'x,y,-z+1/2',&
    '',&
    '* 11:a      C2h^2         P21/m:a = P21/m11           -P 2xa',&
    'x,y,z',&
    'x+1/2,-y,-z',&
    '-x,-y,-z',&
    '-x+1/2,y,z',&
    '',&
    '* 12:b1     C2h^3         C2/m:b1 = C12/m1            -C 2y',&
    'x,y,z',&
    '-x,y,-z',&
    '-x,-y,-z',&
    'x,-y,z',&
    '',&
    '* 12:b2     C2h^3         C2/m:b2 = A12/m1            -A 2y',&
    'x,y,z',&
    '-x,y,-z',&
    '-x,-y,-z',&
    'x,-y,z',&
    '',&
    '* 12:b3     C2h^3         C2/m:b3 = I12/m1            -I 2y',&
    'x,y,z',&
    '-x,y,-z',&
    '-x,-y,-z',&
    'x,-y,z',&
    '',&
    '* 12:c1     C2h^3         C2/m:c1 = A112/m            -A 2',&
    'x,y,z',&
    '-x,-y,z',&
    '-x,-y,-z',&
    'x,y,-z',&
    '',&
    '* 12:c2     C2h^3         C2/m:c2 = B112/m            -B 2',&
    'x,y,z',&
    '-x,-y,z',&
    '-x,-y,-z',&
    'x,y,-z',&
    '',&
    '* 12:c3     C2h^3         C2/m:c3 = I112/m            -I 2',&
    'x,y,z',&
    '-x,-y,z',&
    '-x,-y,-z',&
    'x,y,-z',&
    '',&
    '* 12:a1     C2h^3         C2/m:a1 = B2/m11            -B 2x',&
    'x,y,z',&
    'x,-y,-z',&
    '-x,-y,-z',&
    '-x,y,z',&
    '',&
    '* 12:a2     C2h^3         C2/m:a2 = C2/m11            -C 2x',&
    'x,y,z',&
    'x,-y,-z',&
    '-x,-y,-z',&
    '-x,y,z',&
    '',&
    '* 12:a3     C2h^3         C2/m:a3 = I2/m11            -I 2x',&
    'x,y,z',&
    'x,-y,-z',&
    '-x,-y,-z',&
    '-x,y,z',&
    '',&
    '* 13:b1     C2h^4         P2/c:b1 = P12/c1            -P 2yc',&
    'x,y,z',&
    '-x,y,-z+1/2',&
    '-x,-y,-z',&
    'x,-y,z+1/2',&
    '',&
    '* 13:b2     C2h^4         P2/c:b2 = P12/n1            -P 2yac',&
    'x,y,z',&
    '-x+1/2,y,-z+1/2',&
    '-x,-y,-z',&
    'x+1/2,-y,z+1/2',&
    '',&
    '* 13:b3     C2h^4         P2/c:b3 = P12/a1            -P 2ya',&
    'x,y,z',&
    '-x+1/2,y,-z',&
    '-x,-y,-z',&
    'x+1/2,-y,z',&
    '',&
    '* 13:c1     C2h^4         P2/c:c1 = P112/a            -P 2a',&
    'x,y,z',&
    '-x+1/2,-y,z',&
    '-x,-y,-z',&
    'x+1/2,y,-z',&
    '',&
    '* 13:c2     C2h^4         P2/c:c2 = P112/n            -P 2ab',&
    'x,y,z',&
    '-x+1/2,-y+1/2,z',&
    '-x,-y,-z',&
    'x+1/2,y+1/2,-z',&
    '',&
    '* 13:c3     C2h^4         P2/c:c3 = P112/b            -P 2b',&
    'x,y,z',&
    '-x,-y+1/2,z',&
    '-x,-y,-z',&
    'x,y+1/2,-z',&
    '',&
    '* 13:a1     C2h^4         P2/c:a1 = P2/b11            -P 2xb',&
    'x,y,z',&
    'x,-y+1/2,-z',&
    '-x,-y,-z',&
    '-x,y+1/2,z',&
    '',&
    '* 13:a2     C2h^4         P2/c:a2 = P2/n11            -P 2xbc',&
    'x,y,z',&
    'x,-y+1/2,-z+1/2',&
    '-x,-y,-z',&
    '-x,y+1/2,z+1/2',&
    '',&
    '* 13:a3     C2h^4         P2/c:a3 = P2/c11            -P 2xc',&
    'x,y,z',&
    'x,-y,-z+1/2',&
    '-x,-y,-z',&
    '-x,y,z+1/2',&
    '',&
    '* 14:b1     C2h^5         P21/c:b1 = P121/c1          -P 2ybc',&
    'x,y,z',&
    '-x,y+1/2,-z+1/2',&
    '-x,-y,-z',&
    'x,-y+1/2,z+1/2',&
    '',&
    '* 14:b2     C2h^5         P21/c:b2 = P121/n1          -P 2yn',&
    'x,y,z',&
    '-x+1/2,y+1/2,-z+1/2',&
    '-x,-y,-z',&
    'x+1/2,-y+1/2,z+1/2',&
    '',&
    '* 14:b3     C2h^5         P21/c:b3 = P121/a1          -P 2yab',&
    'x,y,z',&
    '-x+1/2,y+1/2,-z',&
    '-x,-y,-z',&
    'x+1/2,-y+1/2,z',&
    '',&
    '* 14:c1     C2h^5         P21/c:c1 = P1121/a          -P 2ac',&
    'x,y,z',&
    '-x+1/2,-y,z+1/2',&
    '-x,-y,-z',&
    'x+1/2,y,-z+1/2',&
    '',&
    '* 14:c2     C2h^5         P21/c:c2 = P1121/n          -P 2n',&
    'x,y,z',&
    '-x+1/2,-y+1/2,z+1/2',&
    '-x,-y,-z',&
    'x+1/2,y+1/2,-z+1/2',&
    '',&
    '* 14:c3     C2h^5         P21/c:c3 = P1121/b          -P 2bc',&
    'x,y,z',&
    '-x,-y+1/2,z+1/2',&
    '-x,-y,-z',&
    'x,y+1/2,-z+1/2',&
    '',&
    '* 14:a1     C2h^5         P21/c:a1 = P21/b11          -P 2xab',&
    'x,y,z',&
    'x+1/2,-y+1/2,-z',&
    '-x,-y,-z',&
    '-x+1/2,y+1/2,z',&
    '',&
    '* 14:a2     C2h^5         P21/c:a2 = P21/n11          -P 2xn',&
    'x,y,z',&
    'x+1/2,-y+1/2,-z+1/2',&
    '-x,-y,-z',&
    '-x+1/2,y+1/2,z+1/2',&
    '',&
    '* 14:a3     C2h^5         P21/c:a3 = P21/c11          -P 2xac',&
    'x,y,z',&
    'x+1/2,-y,-z+1/2',&
    '-x,-y,-z',&
    '-x+1/2,y,z+1/2',&
    '',&
    '* 15:b1     C2h^6         C2/c:b1 = C12/c1            -C 2yc',&
    'x,y,z',&
    '-x,y,-z+1/2',&
    '-x,-y,-z',&
    'x,-y,z+1/2',&
    '',&
    '* 15:b2     C2h^6         C2/c:b2 = A12/n1            -A 2yac',&
    'x,y,z',&
    '-x+1/2,y,-z+1/2',&
    '-x,-y,-z',&
    'x+1/2,-y,z+1/2',&
    '',&
    '* 15:b3     C2h^6         C2/c:b3 = I12/a1            -I 2ya',&
    'x,y,z',&
    '-x+1/2,y,-z',&
    '-x,-y,-z',&
    'x+1/2,-y,z',&
    '',&
    '* 15:-b1    C2h^6         C2/c:-b1 = A12/a1           -A 2ya',&
    'x,y,z',&
    '-x+1/2,y,-z',&
    '-x,-y,-z',&
    'x+1/2,-y,z',&
    '',&
    '* 15:-b2    C2h^6         C2/c:-b2 = C12/n1           -C 2ybc',&
    'x,y,z',&
    '-x,y+1/2,-z+1/2',&
    '-x,-y,-z',&
    'x,-y+1/2,z+1/2',&
    '',&
    '* 15:-b3    C2h^6         C2/c:-b3 = I12/c1           -I 2yc',&
    'x,y,z',&
    '-x,y,-z+1/2',&
    '-x,-y,-z',&
    'x,-y,z+1/2',&
    '',&
    '* 15:c1     C2h^6         C2/c:c1 = A112/a            -A 2a',&
    'x,y,z',&
    '-x+1/2,-y,z',&
    '-x,-y,-z',&
    'x+1/2,y,-z',&
    '',&
    '* 15:c2     C2h^6         C2/c:c2 = B112/n            -B 2bc',&
    'x,y,z',&
    '-x,-y+1/2,z+1/2',&
    '-x,-y,-z',&
    'x,y+1/2,-z+1/2',&
    '',&
    '* 15:c3     C2h^6         C2/c:c3 = I112/b            -I 2b',&
    'x,y,z',&
    '-x,-y+1/2,z',&
    '-x,-y,-z',&
    'x,y+1/2,-z',&
    '',&
    '* 15:-c1    C2h^6         C2/c:-c1 = B112/b           -B 2b',&
    'x,y,z',&
    '-x,-y+1/2,z',&
    '-x,-y,-z',&
    'x,y+1/2,-z',&
    '',&
    '* 15:-c2    C2h^6         C2/c:-c2 = A112/n           -A 2ac',&
    'x,y,z',&
    '-x+1/2,-y,z+1/2',&
    '-x,-y,-z',&
    'x+1/2,y,-z+1/2',&
    '',&
    '* 15:-c3    C2h^6         C2/c:-c3 = I112/a           -I 2a',&
    'x,y,z',&
    '-x+1/2,-y,z',&
    '-x,-y,-z',&
    'x+1/2,y,-z',&
    '',&
    '* 15:a1     C2h^6         C2/c:a1 = B2/b11            -B 2xb',&
    'x,y,z',&
    'x,-y+1/2,-z',&
    '-x,-y,-z',&
    '-x,y+1/2,z',&
    '',&
    '* 15:a2     C2h^6         C2/c:a2 = C2/n11            -C 2xbc',&
    'x,y,z',&
    'x,-y+1/2,-z+1/2',&
    '-x,-y,-z',&
    '-x,y+1/2,z+1/2',&
    '',&
    '* 15:a3     C2h^6         C2/c:a3 = I2/c11            -I 2xc',&
    'x,y,z',&
    'x,-y,-z+1/2',&
    '-x,-y,-z',&
    '-x,y,z+1/2',&
    '',&
    '* 15:-a1    C2h^6         C2/c:-a1 = C2/c11           -C 2xc',&
    'x,y,z',&
    'x,-y,-z+1/2',&
    '-x,-y,-z',&
    '-x,y,z+1/2',&
    '',&
    '* 15:-a2    C2h^6         C2/c:-a2 = B2/n11           -B 2xbc',&
    'x,y,z',&
    'x,-y+1/2,-z+1/2',&
    '-x,-y,-z',&
    '-x,y+1/2,z+1/2',&
    '',&
    '* 15:-a3    C2h^6         C2/c:-a3 = I2/b11           -I 2xb',&
    'x,y,z',&
    'x,-y+1/2,-z',&
    '-x,-y,-z',&
    '-x,y+1/2,z',&
    '',&
    '* 16        D2^1          P222                         P 2 2',&
    'x,y,z',&
    '-x,-y,z',&
    'x,-y,-z',&
    '-x,y,-z',&
    '',&
    '* 17        D2^2          P2221                        P 2c 2',&
    'x,y,z',&
    '-x,-y,z+1/2',&
    'x,-y,-z',&
    '-x,y,-z+1/2',&
    '',&
    '* 17:cab    D2^2          P2122                        P 2a 2a',&
    'x,y,z',&
    '-x+1/2,-y,z',&
    'x+1/2,-y,-z',&
    '-x,y,-z',&
    '',&
    '* 17:bca    D2^2          P2212                        P 2 2b',&
    'x,y,z',&
    '-x,-y,z',&
    'x,-y+1/2,-z',&
    '-x,y+1/2,-z',&
    '',&
    '* 18        D2^3          P21212                       P 2 2ab',&
    'x,y,z',&
    '-x,-y,z',&
    'x+1/2,-y+1/2,-z',&
    '-x+1/2,y+1/2,-z',&
    '',&
    '* 18:cab    D2^3          P22121                       P 2bc 2',&
    'x,y,z',&
    '-x,-y+1/2,z+1/2',&
    'x,-y,-z',&
    '-x,y+1/2,-z+1/2',&
    '',&
    '* 18:bca    D2^3          P21221                       P 2ac 2ac',&
    'x,y,z',&
    '-x+1/2,-y,z+1/2',&
    'x+1/2,-y,-z+1/2',&
    '-x,y,-z',&
    '',&
    '* 19        D2^4          P212121                      P 2ac 2ab',&
    'x,y,z',&
    '-x+1/2,-y,z+1/2',&
    'x+1/2,-y+1/2,-z',&
    '-x,y+1/2,-z+1/2',&
    '',&
    '* 20        D2^5          C2221                        C 2c 2',&
    'x,y,z',&
    '-x,-y,z+1/2',&
    'x,-y,-z',&
    '-x,y,-z+1/2',&
    '',&
    '* 20:cab    D2^5          A2122                        A 2a 2a',&
    'x,y,z',&
    '-x+1/2,-y,z',&
    'x+1/2,-y,-z',&
    '-x,y,-z',&
    '',&
    '* 20:bca    D2^5          B2212                        B 2 2b',&
    'x,y,z',&
    '-x,-y,z',&
    'x,-y+1/2,-z',&
    '-x,y+1/2,-z',&
    '',&
    '* 21        D2^6          C222                         C 2 2',&
    'x,y,z',&
    '-x,-y,z',&
    'x,-y,-z',&
    '-x,y,-z',&
    '',&
    '* 21:cab    D2^6          A222                         A 2 2',&
    'x,y,z',&
    '-x,-y,z',&
    'x,-y,-z',&
    '-x,y,-z',&
    '',&
    '* 21:bca    D2^6          B222                         B 2 2',&
    'x,y,z',&
    '-x,-y,z',&
    'x,-y,-z',&
    '-x,y,-z',&
    '',&
    '* 22        D2^7          F222                         F 2 2',&
    'x,y,z',&
    '-x,-y,z',&
    'x,-y,-z',&
    '-x,y,-z',&
    '',&
    '* 23        D2^8          I222                         I 2 2',&
    'x,y,z',&
    '-x,-y,z',&
    'x,-y,-z',&
    '-x,y,-z',&
    '',&
    '* 24        D2^9          I212121                      I 2b 2c',&
    'x,y,z',&
    '-x,-y+1/2,z',&
    'x,-y,-z+1/2',&
    '-x+1/2,y,-z',&
    '',&
    '* 25        C2v^1         Pmm2                         P 2 -2',&
    'x,y,z',&
    '-x,-y,z',&
    '-x,y,z',&
    'x,-y,z',&
    '',&
    '* 25:cab    C2v^1         P2mm                         P -2 2',&
    'x,y,z',&
    'x,-y,-z',&
    'x,y,-z',&
    'x,-y,z',&
    '',&
    '* 25:bca    C2v^1         Pm2m                         P -2 -2',&
    'x,y,z',&
    '-x,y,-z',&
    'x,y,-z',&
    '-x,y,z',&
    '',&
    '* 26        C2v^2         Pmc21                        P 2c -2',&
    'x,y,z',&
    '-x,-y,z+1/2',&
    '-x,y,z',&
    'x,-y,z+1/2',&
    '',&
    '* 26:ba-c   C2v^2         Pcm21                        P 2c -2c',&
    'x,y,z',&
    '-x,-y,z+1/2',&
    '-x,y,z+1/2',&
    'x,-y,z',&
    '',&
    '* 26:cab    C2v^2         P21ma                        P -2a 2a',&
    'x,y,z',&
    'x+1/2,-y,-z',&
    'x+1/2,y,-z',&
    'x,-y,z',&
    '',&
    '* 26:-cba   C2v^2         P21am                        P -2 2a',&
    'x,y,z',&
    'x+1/2,-y,-z',&
    'x,y,-z',&
    'x+1/2,-y,z',&
    '',&
    '* 26:bca    C2v^2         Pb21m                        P -2 -2b',&
    'x,y,z',&
    '-x,y+1/2,-z',&
    'x,y,-z',&
    '-x,y+1/2,z',&
    '',&
    '* 26:a-cb   C2v^2         Pm21b                        P -2b -2',&
    'x,y,z',&
    '-x,y+1/2,-z',&
    'x,y+1/2,-z',&
    '-x,y,z',&
    '',&
    '* 27        C2v^3         Pcc2                         P 2 -2c',&
    'x,y,z',&
    '-x,-y,z',&
    '-x,y,z+1/2',&
    'x,-y,z+1/2',&
    '',&
    '* 27:cab    C2v^3         P2aa                         P -2a 2',&
    'x,y,z',&
    'x,-y,-z',&
    'x+1/2,y,-z',&
    'x+1/2,-y,z',&
    '',&
    '* 27:bca    C2v^3         Pb2b                         P -2b -2b',&
    'x,y,z',&
    '-x,y,-z',&
    'x,y+1/2,-z',&
    '-x,y+1/2,z',&
    '',&
    '* 28        C2v^4         Pma2                         P 2 -2a',&
    'x,y,z',&
    '-x,-y,z',&
    '-x+1/2,y,z',&
    'x+1/2,-y,z',&
    '',&
    '* 28:ba-c   C2v^4         Pbm2                         P 2 -2b',&
    'x,y,z',&
    '-x,-y,z',&
    '-x,y+1/2,z',&
    'x,-y+1/2,z',&
    '',&
    '* 28:cab    C2v^4         P2mb                         P -2b 2',&
    'x,y,z',&
    'x,-y,-z',&
    'x,y+1/2,-z',&
    'x,-y+1/2,z',&
    '',&
    '* 28:-cba   C2v^4         P2cm                         P -2c 2',&
    'x,y,z',&
    'x,-y,-z',&
    'x,y,-z+1/2',&
    'x,-y,z+1/2',&
    '',&
    '* 28:bca    C2v^4         Pc2m                         P -2c -2c',&
    'x,y,z',&
    '-x,y,-z',&
    'x,y,-z+1/2',&
    '-x,y,z+1/2',&
    '',&
    '* 28:a-cb   C2v^4         Pm2a                         P -2a -2a',&
    'x,y,z',&
    '-x,y,-z',&
    'x+1/2,y,-z',&
    '-x+1/2,y,z',&
    '',&
    '* 29        C2v^5         Pca21                        P 2c -2ac',&
    'x,y,z',&
    '-x,-y,z+1/2',&
    '-x+1/2,y,z+1/2',&
    'x+1/2,-y,z',&
    '',&
    '* 29:ba-c   C2v^5         Pbc21                        P 2c -2b',&
    'x,y,z',&
    '-x,-y,z+1/2',&
    '-x,y+1/2,z',&
    'x,-y+1/2,z+1/2',&
    '',&
    '* 29:cab    C2v^5         P21ab                        P -2b 2a',&
    'x,y,z',&
    'x+1/2,-y,-z',&
    'x,y+1/2,-z',&
    'x+1/2,-y+1/2,z',&
    '',&
    '* 29:-cba   C2v^5         P21ca                        P -2ac 2a',&
    'x,y,z',&
    'x+1/2,-y,-z',&
    'x+1/2,y,-z+1/2',&
    'x,-y,z+1/2',&
    '',&
    '* 29:bca    C2v^5         Pc21b                        P -2bc -2c',&
    'x,y,z',&
    '-x,y+1/2,-z',&
    'x,y+1/2,-z+1/2',&
    '-x,y,z+1/2',&
    '',&
    '* 29:a-cb   C2v^5         Pb21a                        P -2a -2ab',&
    'x,y,z',&
    '-x,y+1/2,-z',&
    'x+1/2,y,-z',&
    '-x+1/2,y+1/2,z',&
    '',&
    '* 30        C2v^6         Pnc2                         P 2 -2bc',&
    'x,y,z',&
    '-x,-y,z',&
    '-x,y+1/2,z+1/2',&
    'x,-y+1/2,z+1/2',&
    '',&
    '* 30:ba-c   C2v^6         Pcn2                         P 2 -2ac',&
    'x,y,z',&
    '-x,-y,z',&
    '-x+1/2,y,z+1/2',&
    'x+1/2,-y,z+1/2',&
    '',&
    '* 30:cab    C2v^6         P2na                         P -2ac 2',&
    'x,y,z',&
    'x,-y,-z',&
    'x+1/2,y,-z+1/2',&
    'x+1/2,-y,z+1/2',&
    '',&
    '* 30:-cba   C2v^6         P2an                         P -2ab 2',&
    'x,y,z',&
    'x,-y,-z',&
    'x+1/2,y+1/2,-z',&
    'x+1/2,-y+1/2,z',&
    '',&
    '* 30:bca    C2v^6         Pb2n                         P -2ab -2ab',&
    'x,y,z',&
    '-x,y,-z',&
    'x+1/2,y+1/2,-z',&
    '-x+1/2,y+1/2,z',&
    '',&
    '* 30:a-cb   C2v^6         Pn2b                         P -2bc -2bc',&
    'x,y,z',&
    '-x,y,-z',&
    'x,y+1/2,-z+1/2',&
    '-x,y+1/2,z+1/2',&
    '',&
    '* 31        C2v^7         Pmn21                        P 2ac -2',&
    'x,y,z',&
    '-x+1/2,-y,z+1/2',&
    '-x,y,z',&
    'x+1/2,-y,z+1/2',&
    '',&
    '* 31:ba-c   C2v^7         Pnm21                        P 2bc -2bc',&
    'x,y,z',&
    '-x,-y+1/2,z+1/2',&
    '-x,y+1/2,z+1/2',&
    'x,-y,z',&
    '',&
    '* 31:cab    C2v^7         P21mn                        P -2ab 2ab',&
    'x,y,z',&
    'x+1/2,-y+1/2,-z',&
    'x+1/2,y+1/2,-z',&
    'x,-y,z',&
    '',&
    '* 31:-cba   C2v^7         P21nm                        P -2 2ac',&
    'x,y,z',&
    'x+1/2,-y,-z+1/2',&
    'x,y,-z',&
    'x+1/2,-y,z+1/2',&
    '',&
    '* 31:bca    C2v^7         Pn21m                        P -2 -2bc',&
    'x,y,z',&
    '-x,y+1/2,-z+1/2',&
    'x,y,-z',&
    '-x,y+1/2,z+1/2',&
    '',&
    '* 31:a-cb   C2v^7         Pm21n                        P -2ab -2',&
    'x,y,z',&
    '-x+1/2,y+1/2,-z',&
    'x+1/2,y+1/2,-z',&
    '-x,y,z',&
    '',&
    '* 32        C2v^8         Pba2                         P 2 -2ab',&
    'x,y,z',&
    '-x,-y,z',&
    '-x+1/2,y+1/2,z',&
    'x+1/2,-y+1/2,z',&
    '',&
    '* 32:cab    C2v^8         P2cb                         P -2bc 2',&
    'x,y,z',&
    'x,-y,-z',&
    'x,y+1/2,-z+1/2',&
    'x,-y+1/2,z+1/2',&
    '',&
    '* 32:bca    C2v^8         Pc2a                         P -2ac -2ac',&
    'x,y,z',&
    '-x,y,-z',&
    'x+1/2,y,-z+1/2',&
    '-x+1/2,y,z+1/2',&
    '',&
    '* 33        C2v^9         Pna21                        P 2c -2n',&
    'x,y,z',&
    '-x,-y,z+1/2',&
    '-x+1/2,y+1/2,z+1/2',&
    'x+1/2,-y+1/2,z',&
    '',&
    '* 33:ba-c   C2v^9         Pbn21                        P 2c -2ab',&
    'x,y,z',&
    '-x,-y,z+1/2',&
    '-x+1/2,y+1/2,z',&
    'x+1/2,-y+1/2,z+1/2',&
    '',&
    '* 33:cab    C2v^9         P21nb                        P -2bc 2a',&
    'x,y,z',&
    'x+1/2,-y,-z',&
    'x,y+1/2,-z+1/2',&
    'x+1/2,-y+1/2,z+1/2',&
    '',&
    '* 33:-cba   C2v^9         P21cn                        P -2n 2a',&
    'x,y,z',&
    'x+1/2,-y,-z',&
    'x+1/2,y+1/2,-z+1/2',&
    'x,-y+1/2,z+1/2',&
    '',&
    '* 33:bca    C2v^9         Pc21n                        P -2n -2ac',&
    'x,y,z',&
    '-x,y+1/2,-z',&
    'x+1/2,y+1/2,-z+1/2',&
    '-x+1/2,y,z+1/2',&
    '',&
    '* 33:a-cb   C2v^9         Pn21a                        P -2ac -2n',&
    'x,y,z',&
    '-x,y+1/2,-z',&
    'x+1/2,y,-z+1/2',&
    '-x+1/2,y+1/2,z+1/2',&
    '',&
    '* 34        C2v^10        Pnn2                         P 2 -2n',&
    'x,y,z',&
    '-x,-y,z',&
    '-x+1/2,y+1/2,z+1/2',&
    'x+1/2,-y+1/2,z+1/2',&
    '',&
    '* 34:cab    C2v^10        P2nn                         P -2n 2',&
    'x,y,z',&
    'x,-y,-z',&
    'x+1/2,y+1/2,-z+1/2',&
    'x+1/2,-y+1/2,z+1/2',&
    '',&
    '* 34:bca    C2v^10        Pn2n                         P -2n -2n',&
    'x,y,z',&
    '-x,y,-z',&
    'x+1/2,y+1/2,-z+1/2',&
    '-x+1/2,y+1/2,z+1/2',&
    '',&
    '* 35        C2v^11        Cmm2                         C 2 -2',&
    'x,y,z',&
    '-x,-y,z',&
    '-x,y,z',&
    'x,-y,z',&
    '',&
    '* 35:cab    C2v^11        A2mm                         A -2 2',&
    'x,y,z',&
    'x,-y,-z',&
    'x,y,-z',&
    'x,-y,z',&
    '',&
    '* 35:bca    C2v^11        Bm2m                         B -2 -2',&
    'x,y,z',&
    '-x,y,-z',&
    'x,y,-z',&
    '-x,y,z',&
    '',&
    '* 36        C2v^12        Cmc21                        C 2c -2',&
    'x,y,z',&
    '-x,-y,z+1/2',&
    '-x,y,z',&
    'x,-y,z+1/2',&
    '',&
    '* 36:ba-c   C2v^12        Ccm21                        C 2c -2c',&
    'x,y,z',&
    '-x,-y,z+1/2',&
    '-x,y,z+1/2',&
    'x,-y,z',&
    '',&
    '* 36:cab    C2v^12        A21ma                        A -2a 2a',&
    'x,y,z',&
    'x+1/2,-y,-z',&
    'x+1/2,y,-z',&
    'x,-y,z',&
    '',&
    '* 36:-cba   C2v^12        A21am                        A -2 2a',&
    'x,y,z',&
    'x+1/2,-y,-z',&
    'x,y,-z',&
    'x+1/2,-y,z',&
    '',&
    '* 36:bca    C2v^12        Bb21m                        B -2 -2b',&
    'x,y,z',&
    '-x,y+1/2,-z',&
    'x,y,-z',&
    '-x,y+1/2,z',&
    '',&
    '* 36:a-cb   C2v^12        Bm21b                        B -2b -2',&
    'x,y,z',&
    '-x,y+1/2,-z',&
    'x,y+1/2,-z',&
    '-x,y,z',&
    '',&
    '* 37        C2v^13        Ccc2                         C 2 -2c',&
    'x,y,z',&
    '-x,-y,z',&
    '-x,y,z+1/2',&
    'x,-y,z+1/2',&
    '',&
    '* 37:cab    C2v^13        A2aa                         A -2a 2',&
    'x,y,z',&
    'x,-y,-z',&
    'x+1/2,y,-z',&
    'x+1/2,-y,z',&
    '',&
    '* 37:bca    C2v^13        Bb2b                         B -2b -2b',&
    'x,y,z',&
    '-x,y,-z',&
    'x,y+1/2,-z',&
    '-x,y+1/2,z',&
    '',&
    '* 38        C2v^14        Amm2                         A 2 -2',&
    'x,y,z',&
    '-x,-y,z',&
    '-x,y,z',&
    'x,-y,z',&
    '',&
    '* 38:ba-c   C2v^14        Bmm2                         B 2 -2',&
    'x,y,z',&
    '-x,-y,z',&
    '-x,y,z',&
    'x,-y,z',&
    '',&
    '* 38:cab    C2v^14        B2mm                         B -2 2',&
    'x,y,z',&
    'x,-y,-z',&
    'x,y,-z',&
    'x,-y,z',&
    '',&
    '* 38:-cba   C2v^14        C2mm                         C -2 2',&
    'x,y,z',&
    'x,-y,-z',&
    'x,y,-z',&
    'x,-y,z',&
    '',&
    '* 38:bca    C2v^14        Cm2m                         C -2 -2',&
    'x,y,z',&
    '-x,y,-z',&
    'x,y,-z',&
    '-x,y,z',&
    '',&
    '* 38:a-cb   C2v^14        Am2m                         A -2 -2',&
    'x,y,z',&
    '-x,y,-z',&
    'x,y,-z',&
    '-x,y,z',&
    '',&
    '* 39        C2v^15        Abm2                         A 2 -2c',&
    'x,y,z',&
    '-x,-y,z',&
    '-x,y,z+1/2',&
    'x,-y,z+1/2',&
    '',&
    '* 39:ba-c   C2v^15        Bma2                         B 2 -2c',&
    'x,y,z',&
    '-x,-y,z',&
    '-x,y,z+1/2',&
    'x,-y,z+1/2',&
    '',&
    '* 39:cab    C2v^15        B2cm                         B -2c 2',&
    'x,y,z',&
    'x,-y,-z',&
    'x,y,-z+1/2',&
    'x,-y,z+1/2',&
    '',&
    '* 39:-cba   C2v^15        C2mb                         C -2b 2',&
    'x,y,z',&
    'x,-y,-z',&
    'x,y+1/2,-z',&
    'x,-y+1/2,z',&
    '',&
    '* 39:bca    C2v^15        Cm2a                         C -2b -2b',&
    'x,y,z',&
    '-x,y,-z',&
    'x,y+1/2,-z',&
    '-x,y+1/2,z',&
    '',&
    '* 39:a-cb   C2v^15        Ac2m                         A -2c -2c',&
    'x,y,z',&
    '-x,y,-z',&
    'x,y,-z+1/2',&
    '-x,y,z+1/2',&
    '',&
    '* 40        C2v^16        Ama2                         A 2 -2a',&
    'x,y,z',&
    '-x,-y,z',&
    '-x+1/2,y,z',&
    'x+1/2,-y,z',&
    '',&
    '* 40:ba-c   C2v^16        Bbm2                         B 2 -2b',&
    'x,y,z',&
    '-x,-y,z',&
    '-x,y+1/2,z',&
    'x,-y+1/2,z',&
    '',&
    '* 40:cab    C2v^16        B2mb                         B -2b 2',&
    'x,y,z',&
    'x,-y,-z',&
    'x,y+1/2,-z',&
    'x,-y+1/2,z',&
    '',&
    '* 40:-cba   C2v^16        C2cm                         C -2c 2',&
    'x,y,z',&
    'x,-y,-z',&
    'x,y,-z+1/2',&
    'x,-y,z+1/2',&
    '',&
    '* 40:bca    C2v^16        Cc2m                         C -2c -2c',&
    'x,y,z',&
    '-x,y,-z',&
    'x,y,-z+1/2',&
    '-x,y,z+1/2',&
    '',&
    '* 40:a-cb   C2v^16        Am2a                         A -2a -2a',&
    'x,y,z',&
    '-x,y,-z',&
    'x+1/2,y,-z',&
    '-x+1/2,y,z',&
    '',&
    '* 41        C2v^17        Aba2                         A 2 -2ac',&
    'x,y,z',&
    '-x,-y,z',&
    '-x+1/2,y,z+1/2',&
    'x+1/2,-y,z+1/2',&
    '',&
    '* 41:ba-c   C2v^17        Bba2                         B 2 -2bc',&
    'x,y,z',&
    '-x,-y,z',&
    '-x,y+1/2,z+1/2',&
    'x,-y+1/2,z+1/2',&
    '',&
    '* 41:cab    C2v^17        B2cb                         B -2bc 2',&
    'x,y,z',&
    'x,-y,-z',&
    'x,y+1/2,-z+1/2',&
    'x,-y+1/2,z+1/2',&
    '',&
    '* 41:-cba   C2v^17        C2cb                         C -2bc 2',&
    'x,y,z',&
    'x,-y,-z',&
    'x,y+1/2,-z+1/2',&
    'x,-y+1/2,z+1/2',&
    '',&
    '* 41:bca    C2v^17        Cc2a                         C -2bc -2bc',&
    'x,y,z',&
    '-x,y,-z',&
    'x,y+1/2,-z+1/2',&
    '-x,y+1/2,z+1/2',&
    '',&
    '* 41:a-cb   C2v^17        Ac2a                         A -2ac -2ac',&
    'x,y,z',&
    '-x,y,-z',&
    'x+1/2,y,-z+1/2',&
    '-x+1/2,y,z+1/2',&
    '',&
    '* 42        C2v^18        Fmm2                         F 2 -2',&
    'x,y,z',&
    '-x,-y,z',&
    '-x,y,z',&
    'x,-y,z',&
    '',&
    '* 42:cab    C2v^18        F2mm                         F -2 2',&
    'x,y,z',&
    'x,-y,-z',&
    'x,y,-z',&
    'x,-y,z',&
    '',&
    '* 42:bca    C2v^18        Fm2m                         F -2 -2',&
    'x,y,z',&
    '-x,y,-z',&
    'x,y,-z',&
    '-x,y,z',&
    '',&
    '* 43        C2v^19        Fdd2                         F 2 -2d',&
    'x,y,z',&
    '-x,-y,z',&
    '-x+1/4,y+1/4,z+1/4',&
    'x+1/4,-y+1/4,z+1/4',&
    '',&
    '* 43:cab    C2v^19        F2dd                         F -2d 2',&
    'x,y,z',&
    'x,-y,-z',&
    'x+1/4,y+1/4,-z+1/4',&
    'x+1/4,-y+1/4,z+1/4',&
    '',&
    '* 43:bca    C2v^19        Fd2d                         F -2d -2d',&
    'x,y,z',&
    '-x,y,-z',&
    'x+1/4,y+1/4,-z+1/4',&
    '-x+1/4,y+1/4,z+1/4',&
    '',&
    '* 44        C2v^20        Imm2                         I 2 -2',&
    'x,y,z',&
    '-x,-y,z',&
    '-x,y,z',&
    'x,-y,z',&
    '',&
    '* 44:cab    C2v^20        I2mm                         I -2 2',&
    'x,y,z',&
    'x,-y,-z',&
    'x,y,-z',&
    'x,-y,z',&
    '',&
    '* 44:bca    C2v^20        Im2m                         I -2 -2',&
    'x,y,z',&
    '-x,y,-z',&
    'x,y,-z',&
    '-x,y,z',&
    '',&
    '* 45        C2v^21        Iba2                         I 2 -2c',&
    'x,y,z',&
    '-x,-y,z',&
    '-x,y,z+1/2',&
    'x,-y,z+1/2',&
    '',&
    '* 45:cab    C2v^21        I2cb                         I -2a 2',&
    'x,y,z',&
    'x,-y,-z',&
    'x+1/2,y,-z',&
    'x+1/2,-y,z',&
    '',&
    '* 45:bca    C2v^21        Ic2a                         I -2b -2b',&
    'x,y,z',&
    '-x,y,-z',&
    'x,y+1/2,-z',&
    '-x,y+1/2,z',&
    '',&
    '* 46        C2v^22        Ima2                         I 2 -2a',&
    'x,y,z',&
    '-x,-y,z',&
    '-x+1/2,y,z',&
    'x+1/2,-y,z',&
    '',&
    '* 46:ba-c   C2v^22        Ibm2                         I 2 -2b',&
    'x,y,z',&
    '-x,-y,z',&
    '-x,y+1/2,z',&
    'x,-y+1/2,z',&
    '',&
    '* 46:cab    C2v^22        I2mb                         I -2b 2',&
    'x,y,z',&
    'x,-y,-z',&
    'x,y+1/2,-z',&
    'x,-y+1/2,z',&
    '',&
    '* 46:-cba   C2v^22        I2cm                         I -2c 2',&
    'x,y,z',&
    'x,-y,-z',&
    'x,y,-z+1/2',&
    'x,-y,z+1/2',&
    '',&
    '* 46:bca    C2v^22        Ic2m                         I -2c -2c',&
    'x,y,z',&
    '-x,y,-z',&
    'x,y,-z+1/2',&
    '-x,y,z+1/2',&
    '',&
    '* 46:a-cb   C2v^22        Im2a                         I -2a -2a',&
    'x,y,z',&
    '-x,y,-z',&
    'x+1/2,y,-z',&
    '-x+1/2,y,z',&
    '',&
    '* 47        D2h^1         Pmmm                        -P 2 2',&
    'x,y,z',&
    '-x,-y,z',&
    'x,-y,-z',&
    '-x,y,-z',&
    '-x,-y,-z',&
    'x,y,-z',&
    '-x,y,z',&
    'x,-y,z',&
    '',&
    '* 48:1      D2h^2         Pnnn:1                       P 2 2 -1n',&
    'x,y,z',&
    '-x+1/2,-y+1/2,-z+1/2',&
    '-x,-y,z',&
    'x,-y,-z',&
    '-x,y,-z',&
    'x+1/2,y+1/2,-z+1/2',&
    '-x+1/2,y+1/2,z+1/2',&
    'x+1/2,-y+1/2,z+1/2',&
    '',&
    '* 48:2      D2h^2         Pnnn:2                      -P 2ab 2bc',&
    'x,y,z',&
    '-x+1/2,-y+1/2,z',&
    'x,-y+1/2,-z+1/2',&
    '-x+1/2,y,-z+1/2',&
    '-x,-y,-z',&
    'x+1/2,y+1/2,-z',&
    '-x,y+1/2,z+1/2',&
    'x+1/2,-y,z+1/2',&
    '',&
    '* 49        D2h^3         Pccm                        -P 2 2c',&
    'x,y,z',&
    '-x,-y,z',&
    'x,-y,-z+1/2',&
    '-x,y,-z+1/2',&
    '-x,-y,-z',&
    'x,y,-z',&
    '-x,y,z+1/2',&
    'x,-y,z+1/2',&
    '',&
    '* 49:cab    D2h^3         Pmaa                        -P 2a 2',&
    'x,y,z',&
    '-x+1/2,-y,z',&
    'x,-y,-z',&
    '-x+1/2,y,-z',&
    '-x,-y,-z',&
    'x+1/2,y,-z',&
    '-x,y,z',&
    'x+1/2,-y,z',&
    '',&
    '* 49:bca    D2h^3         Pbmb                        -P 2b 2b',&
    'x,y,z',&
    '-x,-y+1/2,z',&
    'x,-y+1/2,-z',&
    '-x,y,-z',&
    '-x,-y,-z',&
    'x,y+1/2,-z',&
    '-x,y+1/2,z',&
    'x,-y,z',&
    '',&
    '* 50:1      D2h^4         Pban:1                       P 2 2 -1ab',&
    'x,y,z',&
    '-x+1/2,-y+1/2,-z',&
    '-x,-y,z',&
    'x,-y,-z',&
    '-x,y,-z',&
    'x+1/2,y+1/2,-z',&
    '-x+1/2,y+1/2,z',&
    'x+1/2,-y+1/2,z',&
    '',&
    '* 50:2      D2h^4         Pban:2                      -P 2ab 2b',&
    'x,y,z',&
    '-x+1/2,-y+1/2,z',&
    'x,-y+1/2,-z',&
    '-x+1/2,y,-z',&
    '-x,-y,-z',&
    'x+1/2,y+1/2,-z',&
    '-x,y+1/2,z',&
    'x+1/2,-y,z',&
    '',&
    '* 50:1cab   D2h^4         Pncb:1                       P 2 2 -1bc',&
    'x,y,z',&
    '-x,-y+1/2,-z+1/2',&
    '-x,-y,z',&
    'x,-y,-z',&
    '-x,y,-z',&
    'x,y+1/2,-z+1/2',&
    '-x,y+1/2,z+1/2',&
    'x,-y+1/2,z+1/2',&
    '',&
    '* 50:2cab   D2h^4         Pncb:2                      -P 2b 2bc',&
    'x,y,z',&
    '-x,-y+1/2,z',&
    'x,-y+1/2,-z+1/2',&
    '-x,y,-z+1/2',&
    '-x,-y,-z',&
    'x,y+1/2,-z',&
    '-x,y+1/2,z+1/2',&
    'x,-y,z+1/2',&
    '',&
    '* 50:1bca   D2h^4         Pcna:1                       P 2 2 -1ac',&
    'x,y,z',&
    '-x+1/2,-y,-z+1/2',&
    '-x,-y,z',&
    'x,-y,-z',&
    '-x,y,-z',&
    'x+1/2,y,-z+1/2',&
    '-x+1/2,y,z+1/2',&
    'x+1/2,-y,z+1/2',&
    '',&
    '* 50:2bca   D2h^4         Pcna:2                      -P 2a 2c',&
    'x,y,z',&
    '-x+1/2,-y,z',&
    'x,-y,-z+1/2',&
    '-x+1/2,y,-z+1/2',&
    '-x,-y,-z',&
    'x+1/2,y,-z',&
    '-x,y,z+1/2',&
    'x+1/2,-y,z+1/2',&
    '',&
    '* 51        D2h^5         Pmma                        -P 2a 2a',&
    'x,y,z',&
    '-x+1/2,-y,z',&
    'x+1/2,-y,-z',&
    '-x,y,-z',&
    '-x,-y,-z',&
    'x+1/2,y,-z',&
    '-x+1/2,y,z',&
    'x,-y,z',&
    '',&
    '* 51:ba-c   D2h^5         Pmmb                        -P 2b 2',&
    'x,y,z',&
    '-x,-y+1/2,z',&
    'x,-y,-z',&
    '-x,y+1/2,-z',&
    '-x,-y,-z',&
    'x,y+1/2,-z',&
    '-x,y,z',&
    'x,-y+1/2,z',&
    '',&
    '* 51:cab    D2h^5         Pbmm                        -P 2 2b',&
    'x,y,z',&
    '-x,-y,z',&
    'x,-y+1/2,-z',&
    '-x,y+1/2,-z',&
    '-x,-y,-z',&
    'x,y,-z',&
    '-x,y+1/2,z',&
    'x,-y+1/2,z',&
    '',&
    '* 51:-cba   D2h^5         Pcmm                        -P 2c 2c',&
    'x,y,z',&
    '-x,-y,z+1/2',&
    'x,-y,-z+1/2',&
    '-x,y,-z',&
    '-x,-y,-z',&
    'x,y,-z+1/2',&
    '-x,y,z+1/2',&
    'x,-y,z',&
    '',&
    '* 51:bca    D2h^5         Pmcm                        -P 2c 2',&
    'x,y,z',&
    '-x,-y,z+1/2',&
    'x,-y,-z',&
    '-x,y,-z+1/2',&
    '-x,-y,-z',&
    'x,y,-z+1/2',&
    '-x,y,z',&
    'x,-y,z+1/2',&
    '',&
    '* 51:a-cb   D2h^5         Pmam                        -P 2 2a',&
    'x,y,z',&
    '-x,-y,z',&
    'x+1/2,-y,-z',&
    '-x+1/2,y,-z',&
    '-x,-y,-z',&
    'x,y,-z',&
    '-x+1/2,y,z',&
    'x+1/2,-y,z',&
    '',&
    '* 52        D2h^6         Pnna                        -P 2a 2bc',&
    'x,y,z',&
    '-x+1/2,-y,z',&
    'x,-y+1/2,-z+1/2',&
    '-x+1/2,y+1/2,-z+1/2',&
    '-x,-y,-z',&
    'x+1/2,y,-z',&
    '-x,y+1/2,z+1/2',&
    'x+1/2,-y+1/2,z+1/2',&
    '',&
    '* 52:ba-c   D2h^6         Pnnb                        -P 2b 2n',&
    'x,y,z',&
    '-x,-y+1/2,z',&
    'x+1/2,-y+1/2,-z+1/2',&
    '-x+1/2,y,-z+1/2',&
    '-x,-y,-z',&
    'x,y+1/2,-z',&
    '-x+1/2,y+1/2,z+1/2',&
    'x+1/2,-y,z+1/2',&
    '',&
    '* 52:cab    D2h^6         Pbnn                        -P 2n 2b',&
    'x,y,z',&
    '-x+1/2,-y+1/2,z+1/2',&
    'x,-y+1/2,-z',&
    '-x+1/2,y,-z+1/2',&
    '-x,-y,-z',&
    'x+1/2,y+1/2,-z+1/2',&
    '-x,y+1/2,z',&
    'x+1/2,-y,z+1/2',&
    '',&
    '* 52:-cba   D2h^6         Pcnn                        -P 2ab 2c',&
    'x,y,z',&
    '-x+1/2,-y+1/2,z',&
    'x,-y,-z+1/2',&
    '-x+1/2,y+1/2,-z+1/2',&
    '-x,-y,-z',&
    'x+1/2,y+1/2,-z',&
    '-x,y,z+1/2',&
    'x+1/2,-y+1/2,z+1/2',&
    '',&
    '* 52:bca    D2h^6         Pncn                        -P 2ab 2n',&
    'x,y,z',&
    '-x+1/2,-y+1/2,z',&
    'x+1/2,-y+1/2,-z+1/2',&
    '-x,y,-z+1/2',&
    '-x,-y,-z',&
    'x+1/2,y+1/2,-z',&
    '-x+1/2,y+1/2,z+1/2',&
    'x,-y,z+1/2',&
    '',&
    '* 52:a-cb   D2h^6         Pnan                        -P 2n 2bc',&
    'x,y,z',&
    '-x+1/2,-y+1/2,z+1/2',&
    'x,-y+1/2,-z+1/2',&
    '-x+1/2,y,-z',&
    '-x,-y,-z',&
    'x+1/2,y+1/2,-z+1/2',&
    '-x,y+1/2,z+1/2',&
    'x+1/2,-y,z',&
    '',&
    '* 53        D2h^7         Pmna                        -P 2ac 2',&
    'x,y,z',&
    '-x+1/2,-y,z+1/2',&
    'x,-y,-z',&
    '-x+1/2,y,-z+1/2',&
    '-x,-y,-z',&
    'x+1/2,y,-z+1/2',&
    '-x,y,z',&
    'x+1/2,-y,z+1/2',&
    '',&
    '* 53:ba-c   D2h^7         Pnmb                        -P 2bc 2bc',&
    'x,y,z',&
    '-x,-y+1/2,z+1/2',&
    'x,-y+1/2,-z+1/2',&
    '-x,y,-z',&
    '-x,-y,-z',&
    'x,y+1/2,-z+1/2',&
    '-x,y+1/2,z+1/2',&
    'x,-y,z',&
    '',&
    '* 53:cab    D2h^7         Pbmn                        -P 2ab 2ab',&
    'x,y,z',&
    '-x+1/2,-y+1/2,z',&
    'x+1/2,-y+1/2,-z',&
    '-x,y,-z',&
    '-x,-y,-z',&
    'x+1/2,y+1/2,-z',&
    '-x+1/2,y+1/2,z',&
    'x,-y,z',&
    '',&
    '* 53:-cba   D2h^7         Pcnm                        -P 2 2ac',&
    'x,y,z',&
    '-x,-y,z',&
    'x+1/2,-y,-z+1/2',&
    '-x+1/2,y,-z+1/2',&
    '-x,-y,-z',&
    'x,y,-z',&
    '-x+1/2,y,z+1/2',&
    'x+1/2,-y,z+1/2',&
    '',&
    '* 53:bca    D2h^7         Pncm                        -P 2 2bc',&
    'x,y,z',&
    '-x,-y,z',&
    'x,-y+1/2,-z+1/2',&
    '-x,y+1/2,-z+1/2',&
    '-x,-y,-z',&
    'x,y,-z',&
    '-x,y+1/2,z+1/2',&
    'x,-y+1/2,z+1/2',&
    '',&
    '* 53:a-cb   D2h^7         Pman                        -P 2ab 2',&
    'x,y,z',&
    '-x+1/2,-y+1/2,z',&
    'x,-y,-z',&
    '-x+1/2,y+1/2,-z',&
    '-x,-y,-z',&
    'x+1/2,y+1/2,-z',&
    '-x,y,z',&
    'x+1/2,-y+1/2,z',&
    '',&
    '* 54        D2h^8         Pcca                        -P 2a 2ac',&
    'x,y,z',&
    '-x+1/2,-y,z',&
    'x+1/2,-y,-z+1/2',&
    '-x,y,-z+1/2',&
    '-x,-y,-z',&
    'x+1/2,y,-z',&
    '-x+1/2,y,z+1/2',&
    'x,-y,z+1/2',&
    '',&
    '* 54:ba-c   D2h^8         Pccb                        -P 2b 2c',&
    'x,y,z',&
    '-x,-y+1/2,z',&
    'x,-y,-z+1/2',&
    '-x,y+1/2,-z+1/2',&
    '-x,-y,-z',&
    'x,y+1/2,-z',&
    '-x,y,z+1/2',&
    'x,-y+1/2,z+1/2',&
    '',&
    '* 54:cab    D2h^8         Pbaa                        -P 2a 2b',&
    'x,y,z',&
    '-x+1/2,-y,z',&
    'x,-y+1/2,-z',&
    '-x+1/2,y+1/2,-z',&
    '-x,-y,-z',&
    'x+1/2,y,-z',&
    '-x,y+1/2,z',&
    'x+1/2,-y+1/2,z',&
    '',&
    '* 54:-cba   D2h^8         Pcaa                        -P 2ac 2c',&
    'x,y,z',&
    '-x+1/2,-y,z+1/2',&
    'x,-y,-z+1/2',&
    '-x+1/2,y,-z',&
    '-x,-y,-z',&
    'x+1/2,y,-z+1/2',&
    '-x,y,z+1/2',&
    'x+1/2,-y,z',&
    '',&
    '* 54:bca    D2h^8         Pbcb                        -P 2bc 2b',&
    'x,y,z',&
    '-x,-y+1/2,z+1/2',&
    'x,-y+1/2,-z',&
    '-x,y,-z+1/2',&
    '-x,-y,-z',&
    'x,y+1/2,-z+1/2',&
    '-x,y+1/2,z',&
    'x,-y,z+1/2',&
    '',&
    '* 54:a-cb   D2h^8         Pbab                        -P 2b 2ab',&
    'x,y,z',&
    '-x,-y+1/2,z',&
    'x+1/2,-y+1/2,-z',&
    '-x+1/2,y,-z',&
    '-x,-y,-z',&
    'x,y+1/2,-z',&
    '-x+1/2,y+1/2,z',&
    'x+1/2,-y,z',&
    '',&
    '* 55        D2h^9         Pbam                        -P 2 2ab',&
    'x,y,z',&
    '-x,-y,z',&
    'x+1/2,-y+1/2,-z',&
    '-x+1/2,y+1/2,-z',&
    '-x,-y,-z',&
    'x,y,-z',&
    '-x+1/2,y+1/2,z',&
    'x+1/2,-y+1/2,z',&
    '',&
    '* 55:cab    D2h^9         Pmcb                        -P 2bc 2',&
    'x,y,z',&
    '-x,-y+1/2,z+1/2',&
    'x,-y,-z',&
    '-x,y+1/2,-z+1/2',&
    '-x,-y,-z',&
    'x,y+1/2,-z+1/2',&
    '-x,y,z',&
    'x,-y+1/2,z+1/2',&
    '',&
    '* 55:bca    D2h^9         Pcma                        -P 2ac 2ac',&
    'x,y,z',&
    '-x+1/2,-y,z+1/2',&
    'x+1/2,-y,-z+1/2',&
    '-x,y,-z',&
    '-x,-y,-z',&
    'x+1/2,y,-z+1/2',&
    '-x+1/2,y,z+1/2',&
    'x,-y,z',&
    '',&
    '* 56        D2h^10        Pccn                        -P 2ab 2ac',&
    'x,y,z',&
    '-x+1/2,-y+1/2,z',&
    'x+1/2,-y,-z+1/2',&
    '-x,y+1/2,-z+1/2',&
    '-x,-y,-z',&
    'x+1/2,y+1/2,-z',&
    '-x+1/2,y,z+1/2',&
    'x,-y+1/2,z+1/2',&
    '',&
    '* 56:cab    D2h^10        Pnaa                        -P 2ac 2bc',&
    'x,y,z',&
    '-x+1/2,-y,z+1/2',&
    'x,-y+1/2,-z+1/2',&
    '-x+1/2,y+1/2,-z',&
    '-x,-y,-z',&
    'x+1/2,y,-z+1/2',&
    '-x,y+1/2,z+1/2',&
    'x+1/2,-y+1/2,z',&
    '',&
    '* 56:bca    D2h^10        Pbnb                        -P 2bc 2ab',&
    'x,y,z',&
    '-x,-y+1/2,z+1/2',&
    'x+1/2,-y+1/2,-z',&
    '-x+1/2,y,-z+1/2',&
    '-x,-y,-z',&
    'x,y+1/2,-z+1/2',&
    '-x+1/2,y+1/2,z',&
    'x+1/2,-y,z+1/2',&
    '',&
    '* 57        D2h^11        Pbcm                        -P 2c 2b',&
    'x,y,z',&
    '-x,-y,z+1/2',&
    'x,-y+1/2,-z',&
    '-x,y+1/2,-z+1/2',&
    '-x,-y,-z',&
    'x,y,-z+1/2',&
    '-x,y+1/2,z',&
    'x,-y+1/2,z+1/2',&
    '',&
    '* 57:ba-c   D2h^11        Pcam                        -P 2c 2ac',&
    'x,y,z',&
    '-x,-y,z+1/2',&
    'x+1/2,-y,-z+1/2',&
    '-x+1/2,y,-z',&
    '-x,-y,-z',&
    'x,y,-z+1/2',&
    '-x+1/2,y,z+1/2',&
    'x+1/2,-y,z',&
    '',&
    '* 57:cab    D2h^11        Pmca                        -P 2ac 2a',&
    'x,y,z',&
    '-x+1/2,-y,z+1/2',&
    'x+1/2,-y,-z',&
    '-x,y,-z+1/2',&
    '-x,-y,-z',&
    'x+1/2,y,-z+1/2',&
    '-x+1/2,y,z',&
    'x,-y,z+1/2',&
    '',&
    '* 57:-cba   D2h^11        Pmab                        -P 2b 2a',&
    'x,y,z',&
    '-x,-y+1/2,z',&
    'x+1/2,-y,-z',&
    '-x+1/2,y+1/2,-z',&
    '-x,-y,-z',&
    'x,y+1/2,-z',&
    '-x+1/2,y,z',&
    'x+1/2,-y+1/2,z',&
    '',&
    '* 57:bca    D2h^11        Pbma                        -P 2a 2ab',&
    'x,y,z',&
    '-x+1/2,-y,z',&
    'x+1/2,-y+1/2,-z',&
    '-x,y+1/2,-z',&
    '-x,-y,-z',&
    'x+1/2,y,-z',&
    '-x+1/2,y+1/2,z',&
    'x,-y+1/2,z',&
    '',&
    '* 57:a-cb   D2h^11        Pcmb                        -P 2bc 2c',&
    'x,y,z',&
    '-x,-y+1/2,z+1/2',&
    'x,-y,-z+1/2',&
    '-x,y+1/2,-z',&
    '-x,-y,-z',&
    'x,y+1/2,-z+1/2',&
    '-x,y,z+1/2',&
    'x,-y+1/2,z',&
    '',&
    '* 58        D2h^12        Pnnm                        -P 2 2n',&
    'x,y,z',&
    '-x,-y,z',&
    'x+1/2,-y+1/2,-z+1/2',&
    '-x+1/2,y+1/2,-z+1/2',&
    '-x,-y,-z',&
    'x,y,-z',&
    '-x+1/2,y+1/2,z+1/2',&
    'x+1/2,-y+1/2,z+1/2',&
    '',&
    '* 58:cab    D2h^12        Pmnn                        -P 2n 2',&
    'x,y,z',&
    '-x+1/2,-y+1/2,z+1/2',&
    'x,-y,-z',&
    '-x+1/2,y+1/2,-z+1/2',&
    '-x,-y,-z',&
    'x+1/2,y+1/2,-z+1/2',&
    '-x,y,z',&
    'x+1/2,-y+1/2,z+1/2',&
    '',&
    '* 58:bca    D2h^12        Pnmn                        -P 2n 2n',&
    'x,y,z',&
    '-x+1/2,-y+1/2,z+1/2',&
    'x+1/2,-y+1/2,-z+1/2',&
    '-x,y,-z',&
    '-x,-y,-z',&
    'x+1/2,y+1/2,-z+1/2',&
    '-x+1/2,y+1/2,z+1/2',&
    'x,-y,z',&
    '',&
    '* 59:1      D2h^13        Pmmn:1                       P 2 2ab -1ab',&
    'x,y,z',&
    '-x+1/2,-y+1/2,-z',&
    '-x,-y,z',&
    'x+1/2,-y+1/2,-z',&
    '-x+1/2,y+1/2,-z',&
    'x+1/2,y+1/2,-z',&
    '-x,y,z',&
    'x,-y,z',&
    '',&
    '* 59:2      D2h^13        Pmmn:2                      -P 2ab 2a',&
    'x,y,z',&
    '-x+1/2,-y+1/2,z',&
    'x+1/2,-y,-z',&
    '-x,y+1/2,-z',&
    '-x,-y,-z',&
    'x+1/2,y+1/2,-z',&
    '-x+1/2,y,z',&
    'x,-y+1/2,z',&
    '',&
    '* 59:1cab   D2h^13        Pnmm:1                       P 2bc 2 -1bc',&
    'x,y,z',&
    '-x,-y+1/2,-z+1/2',&
    '-x,-y+1/2,z+1/2',&
    'x,-y,-z',&
    '-x,y+1/2,-z+1/2',&
    'x,y,-z',&
    '-x,y+1/2,z+1/2',&
    'x,-y,z',&
    '',&
    '* 59:2cab   D2h^13        Pnmm:2                      -P 2c 2bc',&
    'x,y,z',&
    '-x,-y,z+1/2',&
    'x,-y+1/2,-z+1/2',&
    '-x,y+1/2,-z',&
    '-x,-y,-z',&
    'x,y,-z+1/2',&
    '-x,y+1/2,z+1/2',&
    'x,-y+1/2,z',&
    '',&
    '* 59:1bca   D2h^13        Pmnm:1                       P 2ac 2ac -1ac',&
    'x,y,z',&
    '-x+1/2,-y,-z+1/2',&
    '-x+1/2,-y,z+1/2',&
    'x+1/2,-y,-z+1/2',&
    '-x,y,-z',&
    'x,y,-z',&
    '-x,y,z',&
    'x+1/2,-y,z+1/2',&
    '',&
    '* 59:2bca   D2h^13        Pmnm:2                      -P 2c 2a',&
    'x,y,z',&
    '-x,-y,z+1/2',&
    'x+1/2,-y,-z',&
    '-x+1/2,y,-z+1/2',&
    '-x,-y,-z',&
    'x,y,-z+1/2',&
    '-x+1/2,y,z',&
    'x+1/2,-y,z+1/2',&
    '',&
    '* 60        D2h^14        Pbcn                        -P 2n 2ab',&
    'x,y,z',&
    '-x+1/2,-y+1/2,z+1/2',&
    'x+1/2,-y+1/2,-z',&
    '-x,y,-z+1/2',&
    '-x,-y,-z',&
    'x+1/2,y+1/2,-z+1/2',&
    '-x+1/2,y+1/2,z',&
    'x,-y,z+1/2',&
    '',&
    '* 60:ba-c   D2h^14        Pcan                        -P 2n 2c',&
    'x,y,z',&
    '-x+1/2,-y+1/2,z+1/2',&
    'x,-y,-z+1/2',&
    '-x+1/2,y+1/2,-z',&
    '-x,-y,-z',&
    'x+1/2,y+1/2,-z+1/2',&
    '-x,y,z+1/2',&
    'x+1/2,-y+1/2,z',&
    '',&
    '* 60:cab    D2h^14        Pnca                        -P 2a 2n',&
    'x,y,z',&
    '-x+1/2,-y,z',&
    'x+1/2,-y+1/2,-z+1/2',&
    '-x,y+1/2,-z+1/2',&
    '-x,-y,-z',&
    'x+1/2,y,-z',&
    '-x+1/2,y+1/2,z+1/2',&
    'x,-y+1/2,z+1/2',&
    '',&
    '* 60:-cba   D2h^14        Pnab                        -P 2bc 2n',&
    'x,y,z',&
    '-x,-y+1/2,z+1/2',&
    'x+1/2,-y+1/2,-z+1/2',&
    '-x+1/2,y,-z',&
    '-x,-y,-z',&
    'x,y+1/2,-z+1/2',&
    '-x+1/2,y+1/2,z+1/2',&
    'x+1/2,-y,z',&
    '',&
    '* 60:bca    D2h^14        Pbna                        -P 2ac 2b',&
    'x,y,z',&
    '-x+1/2,-y,z+1/2',&
    'x,-y+1/2,-z',&
    '-x+1/2,y+1/2,-z+1/2',&
    '-x,-y,-z',&
    'x+1/2,y,-z+1/2',&
    '-x,y+1/2,z',&
    'x+1/2,-y+1/2,z+1/2',&
    '',&
    '* 60:a-cb   D2h^14        Pcnb                        -P 2b 2ac',&
    'x,y,z',&
    '-x,-y+1/2,z',&
    'x+1/2,-y,-z+1/2',&
    '-x+1/2,y+1/2,-z+1/2',&
    '-x,-y,-z',&
    'x,y+1/2,-z',&
    '-x+1/2,y,z+1/2',&
    'x+1/2,-y+1/2,z+1/2',&
    '',&
    '* 61        D2h^15        Pbca                        -P 2ac 2ab',&
    'x,y,z',&
    '-x+1/2,-y,z+1/2',&
    'x+1/2,-y+1/2,-z',&
    '-x,y+1/2,-z+1/2',&
    '-x,-y,-z',&
    'x+1/2,y,-z+1/2',&
    '-x+1/2,y+1/2,z',&
    'x,-y+1/2,z+1/2',&
    '',&
    '* 61:ba-c   D2h^15        Pcab                        -P 2bc 2ac',&
    'x,y,z',&
    '-x,-y+1/2,z+1/2',&
    'x+1/2,-y,-z+1/2',&
    '-x+1/2,y+1/2,-z',&
    '-x,-y,-z',&
    'x,y+1/2,-z+1/2',&
    '-x+1/2,y,z+1/2',&
    'x+1/2,-y+1/2,z',&
    '',&
    '* 62        D2h^16        Pnma                        -P 2ac 2n',&
    'x,y,z',&
    '-x+1/2,-y,z+1/2',&
    'x+1/2,-y+1/2,-z+1/2',&
    '-x,y+1/2,-z',&
    '-x,-y,-z',&
    'x+1/2,y,-z+1/2',&
    '-x+1/2,y+1/2,z+1/2',&
    'x,-y+1/2,z',&
    '',&
    '* 62:ba-c   D2h^16        Pmnb                        -P 2bc 2a',&
    'x,y,z',&
    '-x,-y+1/2,z+1/2',&
    'x+1/2,-y,-z',&
    '-x+1/2,y+1/2,-z+1/2',&
    '-x,-y,-z',&
    'x,y+1/2,-z+1/2',&
    '-x+1/2,y,z',&
    'x+1/2,-y+1/2,z+1/2',&
    '',&
    '* 62:cab    D2h^16        Pbnm                        -P 2c 2ab',&
    'x,y,z',&
    '-x,-y,z+1/2',&
    'x+1/2,-y+1/2,-z',&
    '-x+1/2,y+1/2,-z+1/2',&
    '-x,-y,-z',&
    'x,y,-z+1/2',&
    '-x+1/2,y+1/2,z',&
    'x+1/2,-y+1/2,z+1/2',&
    '',&
    '* 62:-cba   D2h^16        Pcmn                        -P 2n 2ac',&
    'x,y,z',&
    '-x+1/2,-y+1/2,z+1/2',&
    'x+1/2,-y,-z+1/2',&
    '-x,y+1/2,-z',&
    '-x,-y,-z',&
    'x+1/2,y+1/2,-z+1/2',&
    '-x+1/2,y,z+1/2',&
    'x,-y+1/2,z',&
    '',&
    '* 62:bca    D2h^16        Pmcn                        -P 2n 2a',&
    'x,y,z',&
    '-x+1/2,-y+1/2,z+1/2',&
    'x+1/2,-y,-z',&
    '-x,y+1/2,-z+1/2',&
    '-x,-y,-z',&
    'x+1/2,y+1/2,-z+1/2',&
    '-x+1/2,y,z',&
    'x,-y+1/2,z+1/2',&
    '',&
    '* 62:a-cb   D2h^16        Pnam                        -P 2c 2n',&
    'x,y,z',&
    '-x,-y,z+1/2',&
    'x+1/2,-y+1/2,-z+1/2',&
    '-x+1/2,y+1/2,-z',&
    '-x,-y,-z',&
    'x,y,-z+1/2',&
    '-x+1/2,y+1/2,z+1/2',&
    'x+1/2,-y+1/2,z',&
    '',&
    '* 63        D2h^17        Cmcm                        -C 2c 2',&
    'x,y,z',&
    '-x,-y,z+1/2',&
    'x,-y,-z',&
    '-x,y,-z+1/2',&
    '-x,-y,-z',&
    'x,y,-z+1/2',&
    '-x,y,z',&
    'x,-y,z+1/2',&
    '',&
    '* 63:ba-c   D2h^17        Ccmm                        -C 2c 2c',&
    'x,y,z',&
    '-x,-y,z+1/2',&
    'x,-y,-z+1/2',&
    '-x,y,-z',&
    '-x,-y,-z',&
    'x,y,-z+1/2',&
    '-x,y,z+1/2',&
    'x,-y,z',&
    '',&
    '* 63:cab    D2h^17        Amma                        -A 2a 2a',&
    'x,y,z',&
    '-x+1/2,-y,z',&
    'x+1/2,-y,-z',&
    '-x,y,-z',&
    '-x,-y,-z',&
    'x+1/2,y,-z',&
    '-x+1/2,y,z',&
    'x,-y,z',&
    '',&
    '* 63:-cba   D2h^17        Amam                        -A 2 2a',&
    'x,y,z',&
    '-x,-y,z',&
    'x+1/2,-y,-z',&
    '-x+1/2,y,-z',&
    '-x,-y,-z',&
    'x,y,-z',&
    '-x+1/2,y,z',&
    'x+1/2,-y,z',&
    '',&
    '* 63:bca    D2h^17        Bbmm                        -B 2 2b',&
    'x,y,z',&
    '-x,-y,z',&
    'x,-y+1/2,-z',&
    '-x,y+1/2,-z',&
    '-x,-y,-z',&
    'x,y,-z',&
    '-x,y+1/2,z',&
    'x,-y+1/2,z',&
    '',&
    '* 63:a-cb   D2h^17        Bmmb                        -B 2b 2',&
    'x,y,z',&
    '-x,-y+1/2,z',&
    'x,-y,-z',&
    '-x,y+1/2,-z',&
    '-x,-y,-z',&
    'x,y+1/2,-z',&
    '-x,y,z',&
    'x,-y+1/2,z',&
    '',&
    '* 64        D2h^18        Cmca                        -C 2bc 2',&
    'x,y,z',&
    '-x,-y+1/2,z+1/2',&
    'x,-y,-z',&
    '-x,y+1/2,-z+1/2',&
    '-x,-y,-z',&
    'x,y+1/2,-z+1/2',&
    '-x,y,z',&
    'x,-y+1/2,z+1/2',&
    '',&
    '* 64:ba-c   D2h^18        Ccmb                        -C 2bc 2bc',&
    'x,y,z',&
    '-x,-y+1/2,z+1/2',&
    'x,-y+1/2,-z+1/2',&
    '-x,y,-z',&
    '-x,-y,-z',&
    'x,y+1/2,-z+1/2',&
    '-x,y+1/2,z+1/2',&
    'x,-y,z',&
    '',&
    '* 64:cab    D2h^18        Abma                        -A 2ac 2ac',&
    'x,y,z',&
    '-x+1/2,-y,z+1/2',&
    'x+1/2,-y,-z+1/2',&
    '-x,y,-z',&
    '-x,-y,-z',&
    'x+1/2,y,-z+1/2',&
    '-x+1/2,y,z+1/2',&
    'x,-y,z',&
    '',&
    '* 64:-cba   D2h^18        Acam                        -A 2 2ac',&
    'x,y,z',&
    '-x,-y,z',&
    'x+1/2,-y,-z+1/2',&
    '-x+1/2,y,-z+1/2',&
    '-x,-y,-z',&
    'x,y,-z',&
    '-x+1/2,y,z+1/2',&
    'x+1/2,-y,z+1/2',&
    '',&
    '* 64:bca    D2h^18        Bbcm                        -B 2 2bc',&
    'x,y,z',&
    '-x,-y,z',&
    'x,-y+1/2,-z+1/2',&
    '-x,y+1/2,-z+1/2',&
    '-x,-y,-z',&
    'x,y,-z',&
    '-x,y+1/2,z+1/2',&
    'x,-y+1/2,z+1/2',&
    '',&
    '* 64:a-cb   D2h^18        Bmab                        -B 2bc 2',&
    'x,y,z',&
    '-x,-y+1/2,z+1/2',&
    'x,-y,-z',&
    '-x,y+1/2,-z+1/2',&
    '-x,-y,-z',&
    'x,y+1/2,-z+1/2',&
    '-x,y,z',&
    'x,-y+1/2,z+1/2',&
    '',&
    '* 65        D2h^19        Cmmm                        -C 2 2',&
    'x,y,z',&
    '-x,-y,z',&
    'x,-y,-z',&
    '-x,y,-z',&
    '-x,-y,-z',&
    'x,y,-z',&
    '-x,y,z',&
    'x,-y,z',&
    '',&
    '* 65:cab    D2h^19        Ammm                        -A 2 2',&
    'x,y,z',&
    '-x,-y,z',&
    'x,-y,-z',&
    '-x,y,-z',&
    '-x,-y,-z',&
    'x,y,-z',&
    '-x,y,z',&
    'x,-y,z',&
    '',&
    '* 65:bca    D2h^19        Bmmm                        -B 2 2',&
    'x,y,z',&
    '-x,-y,z',&
    'x,-y,-z',&
    '-x,y,-z',&
    '-x,-y,-z',&
    'x,y,-z',&
    '-x,y,z',&
    'x,-y,z',&
    '',&
    '* 66        D2h^20        Cccm                        -C 2 2c',&
    'x,y,z',&
    '-x,-y,z',&
    'x,-y,-z+1/2',&
    '-x,y,-z+1/2',&
    '-x,-y,-z',&
    'x,y,-z',&
    '-x,y,z+1/2',&
    'x,-y,z+1/2',&
    '',&
    '* 66:cab    D2h^20        Amaa                        -A 2a 2',&
    'x,y,z',&
    '-x+1/2,-y,z',&
    'x,-y,-z',&
    '-x+1/2,y,-z',&
    '-x,-y,-z',&
    'x+1/2,y,-z',&
    '-x,y,z',&
    'x+1/2,-y,z',&
    '',&
    '* 66:bca    D2h^20        Bbmb                        -B 2b 2b',&
    'x,y,z',&
    '-x,-y+1/2,z',&
    'x,-y+1/2,-z',&
    '-x,y,-z',&
    '-x,-y,-z',&
    'x,y+1/2,-z',&
    '-x,y+1/2,z',&
    'x,-y,z',&
    '',&
    '* 67        D2h^21        Cmma                        -C 2b 2',&
    'x,y,z',&
    '-x,-y+1/2,z',&
    'x,-y,-z',&
    '-x,y+1/2,-z',&
    '-x,-y,-z',&
    'x,y+1/2,-z',&
    '-x,y,z',&
    'x,-y+1/2,z',&
    '',&
    '* 67:ba-c   D2h^21        Cmmb                        -C 2b 2b',&
    'x,y,z',&
    '-x,-y+1/2,z',&
    'x,-y+1/2,-z',&
    '-x,y,-z',&
    '-x,-y,-z',&
    'x,y+1/2,-z',&
    '-x,y+1/2,z',&
    'x,-y,z',&
    '',&
    '* 67:cab    D2h^21        Abmm                        -A 2c 2c',&
    'x,y,z',&
    '-x,-y,z+1/2',&
    'x,-y,-z+1/2',&
    '-x,y,-z',&
    '-x,-y,-z',&
    'x,y,-z+1/2',&
    '-x,y,z+1/2',&
    'x,-y,z',&
    '',&
    '* 67:-cba   D2h^21        Acmm                        -A 2 2c',&
    'x,y,z',&
    '-x,-y,z',&
    'x,-y,-z+1/2',&
    '-x,y,-z+1/2',&
    '-x,-y,-z',&
    'x,y,-z',&
    '-x,y,z+1/2',&
    'x,-y,z+1/2',&
    '',&
    '* 67:bca    D2h^21        Bmcm                        -B 2 2c',&
    'x,y,z',&
    '-x,-y,z',&
    'x,-y,-z+1/2',&
    '-x,y,-z+1/2',&
    '-x,-y,-z',&
    'x,y,-z',&
    '-x,y,z+1/2',&
    'x,-y,z+1/2',&
    '',&
    '* 67:a-cb   D2h^21        Bmam                        -B 2c 2',&
    'x,y,z',&
    '-x,-y,z+1/2',&
    'x,-y,-z',&
    '-x,y,-z+1/2',&
    '-x,-y,-z',&
    'x,y,-z+1/2',&
    '-x,y,z',&
    'x,-y,z+1/2',&
    '',&
    '* 68:1      D2h^22        Ccca:1                       C 2 2 -1bc',&
    'x,y,z',&
    '-x,-y+1/2,-z+1/2',&
    '-x,-y,z',&
    'x,-y,-z',&
    '-x,y,-z',&
    'x,y+1/2,-z+1/2',&
    '-x,y+1/2,z+1/2',&
    'x,-y+1/2,z+1/2',&
    '',&
    '* 68:2      D2h^22        Ccca:2                      -C 2b 2bc',&
    'x,y,z',&
    '-x,-y+1/2,z',&
    'x,-y+1/2,-z+1/2',&
    '-x,y,-z+1/2',&
    '-x,-y,-z',&
    'x,y+1/2,-z',&
    '-x,y+1/2,z+1/2',&
    'x,-y,z+1/2',&
    '',&
    '* 68:1ba-c  D2h^22        Cccb:1                       C 2 2 -1bc',&
    'x,y,z',&
    '-x,-y+1/2,-z+1/2',&
    '-x,-y,z',&
    'x,-y,-z',&
    '-x,y,-z',&
    'x,y+1/2,-z+1/2',&
    '-x,y+1/2,z+1/2',&
    'x,-y+1/2,z+1/2',&
    '',&
    '* 68:2ba-c  D2h^22        Cccb:2                      -C 2b 2c',&
    'x,y,z',&
    '-x,-y+1/2,z',&
    'x,-y,-z+1/2',&
    '-x,y+1/2,-z+1/2',&
    '-x,-y,-z',&
    'x,y+1/2,-z',&
    '-x,y,z+1/2',&
    'x,-y+1/2,z+1/2',&
    '',&
    '* 68:1cab   D2h^22        Abaa:1                       A 2 2 -1ac',&
    'x,y,z',&
    '-x+1/2,-y,-z+1/2',&
    '-x,-y,z',&
    'x,-y,-z',&
    '-x,y,-z',&
    'x+1/2,y,-z+1/2',&
    '-x+1/2,y,z+1/2',&
    'x+1/2,-y,z+1/2',&
    '',&
    '* 68:2cab   D2h^22        Abaa:2                      -A 2a 2c',&
    'x,y,z',&
    '-x+1/2,-y,z',&
    'x,-y,-z+1/2',&
    '-x+1/2,y,-z+1/2',&
    '-x,-y,-z',&
    'x+1/2,y,-z',&
    '-x,y,z+1/2',&
    'x+1/2,-y,z+1/2',&
    '',&
    '* 68:1-cba  D2h^22        Acaa:1                       A 2 2 -1ac',&
    'x,y,z',&
    '-x+1/2,-y,-z+1/2',&
    '-x,-y,z',&
    'x,-y,-z',&
    '-x,y,-z',&
    'x+1/2,y,-z+1/2',&
    '-x+1/2,y,z+1/2',&
    'x+1/2,-y,z+1/2',&
    '',&
    '* 68:2-cba  D2h^22        Acaa:2                      -A 2ac 2c',&
    'x,y,z',&
    '-x+1/2,-y,z+1/2',&
    'x,-y,-z+1/2',&
    '-x+1/2,y,-z',&
    '-x,-y,-z',&
    'x+1/2,y,-z+1/2',&
    '-x,y,z+1/2',&
    'x+1/2,-y,z',&
    '',&
    '* 68:1bca   D2h^22        Bbcb:1                       B 2 2 -1bc',&
    'x,y,z',&
    '-x,-y+1/2,-z+1/2',&
    '-x,-y,z',&
    'x,-y,-z',&
    '-x,y,-z',&
    'x,y+1/2,-z+1/2',&
    '-x,y+1/2,z+1/2',&
    'x,-y+1/2,z+1/2',&
    '',&
    '* 68:2bca   D2h^22        Bbcb:2                      -B 2bc 2b',&
    'x,y,z',&
    '-x,-y+1/2,z+1/2',&
    'x,-y+1/2,-z',&
    '-x,y,-z+1/2',&
    '-x,-y,-z',&
    'x,y+1/2,-z+1/2',&
    '-x,y+1/2,z',&
    'x,-y,z+1/2',&
    '',&
    '* 68:1a-cb  D2h^22        Bbab:1                       B 2 2 -1bc',&
    'x,y,z',&
    '-x,-y+1/2,-z+1/2',&
    '-x,-y,z',&
    'x,-y,-z',&
    '-x,y,-z',&
    'x,y+1/2,-z+1/2',&
    '-x,y+1/2,z+1/2',&
    'x,-y+1/2,z+1/2',&
    '',&
    '* 68:2a-cb  D2h^22        Bbab:2                      -B 2b 2bc',&
    'x,y,z',&
    '-x,-y+1/2,z',&
    'x,-y+1/2,-z+1/2',&
    '-x,y,-z+1/2',&
    '-x,-y,-z',&
    'x,y+1/2,-z',&
    '-x,y+1/2,z+1/2',&
    'x,-y,z+1/2',&
    '',&
    '* 69        D2h^23        Fmmm                        -F 2 2',&
    'x,y,z',&
    '-x,-y,z',&
    'x,-y,-z',&
    '-x,y,-z',&
    '-x,-y,-z',&
    'x,y,-z',&
    '-x,y,z',&
    'x,-y,z',&
    '',&
    '* 70:1      D2h^24        Fddd:1                       F 2 2 -1d',&
    'x,y,z',&
    '-x+1/4,-y+1/4,-z+1/4',&
    '-x,-y,z',&
    'x,-y,-z',&
    '-x,y,-z',&
    'x+1/4,y+1/4,-z+1/4',&
    '-x+1/4,y+1/4,z+1/4',&
    'x+1/4,-y+1/4,z+1/4',&
    '',&
    '* 70:2      D2h^24        Fddd:2                      -F 2uv 2vw',&
    'x,y,z',&
    '-x+1/4,-y+1/4,z',&
    'x,-y+1/4,-z+1/4',&
    '-x+1/4,y,-z+1/4',&
    '-x,-y,-z',&
    'x+3/4,y+3/4,-z',&
    '-x,y+3/4,z+3/4',&
    'x+3/4,-y,z+3/4',&
    '',&
    '* 71        D2h^25        Immm                        -I 2 2',&
    'x,y,z',&
    '-x,-y,z',&
    'x,-y,-z',&
    '-x,y,-z',&
    '-x,-y,-z',&
    'x,y,-z',&
    '-x,y,z',&
    'x,-y,z',&
    '',&
    '* 72        D2h^26        Ibam                        -I 2 2c',&
    'x,y,z',&
    '-x,-y,z',&
    'x,-y,-z+1/2',&
    '-x,y,-z+1/2',&
    '-x,-y,-z',&
    'x,y,-z',&
    '-x,y,z+1/2',&
    'x,-y,z+1/2',&
    '',&
    '* 72:cab    D2h^26        Imcb                        -I 2a 2',&
    'x,y,z',&
    '-x+1/2,-y,z',&
    'x,-y,-z',&
    '-x+1/2,y,-z',&
    '-x,-y,-z',&
    'x+1/2,y,-z',&
    '-x,y,z',&
    'x+1/2,-y,z',&
    '',&
    '* 72:bca    D2h^26        Icma                        -I 2b 2b',&
    'x,y,z',&
    '-x,-y+1/2,z',&
    'x,-y+1/2,-z',&
    '-x,y,-z',&
    '-x,-y,-z',&
    'x,y+1/2,-z',&
    '-x,y+1/2,z',&
    'x,-y,z',&
    '',&
    '* 73        D2h^27        Ibca                        -I 2b 2c',&
    'x,y,z',&
    '-x,-y+1/2,z',&
    'x,-y,-z+1/2',&
    '-x+1/2,y,-z',&
    '-x,-y,-z',&
    'x,y+1/2,-z',&
    '-x,y,z+1/2',&
    'x+1/2,-y,z',&
    '',&
    '* 73:ba-c   D2h^27        Icab                        -I 2a 2b',&
    'x,y,z',&
    '-x+1/2,-y,z',&
    'x,-y+1/2,-z',&
    '-x,y,-z+1/2',&
    '-x,-y,-z',&
    'x+1/2,y,-z',&
    '-x,y+1/2,z',&
    'x,-y,z+1/2',&
    '',&
    '* 74        D2h^28        Imma                        -I 2b 2',&
    'x,y,z',&
    '-x,-y+1/2,z',&
    'x,-y,-z',&
    '-x,y+1/2,-z',&
    '-x,-y,-z',&
    'x,y+1/2,-z',&
    '-x,y,z',&
    'x,-y+1/2,z',&
    '',&
    '* 74:ba-c   D2h^28        Immb                        -I 2a 2a',&
    'x,y,z',&
    '-x+1/2,-y,z',&
    'x+1/2,-y,-z',&
    '-x,y,-z',&
    '-x,-y,-z',&
    'x+1/2,y,-z',&
    '-x+1/2,y,z',&
    'x,-y,z',&
    '',&
    '* 74:cab    D2h^28        Ibmm                        -I 2c 2c',&
    'x,y,z',&
    '-x,-y,z+1/2',&
    'x,-y,-z+1/2',&
    '-x,y,-z',&
    '-x,-y,-z',&
    'x,y,-z+1/2',&
    '-x,y,z+1/2',&
    'x,-y,z',&
    '',&
    '* 74:-cba   D2h^28        Icmm                        -I 2 2b',&
    'x,y,z',&
    '-x,-y,z',&
    'x,-y+1/2,-z',&
    '-x,y+1/2,-z',&
    '-x,-y,-z',&
    'x,y,-z',&
    '-x,y+1/2,z',&
    'x,-y+1/2,z',&
    '',&
    '* 74:bca    D2h^28        Imcm                        -I 2 2a',&
    'x,y,z',&
    '-x,-y,z',&
    'x+1/2,-y,-z',&
    '-x+1/2,y,-z',&
    '-x,-y,-z',&
    'x,y,-z',&
    '-x+1/2,y,z',&
    'x+1/2,-y,z',&
    '',&
    '* 74:a-cb   D2h^28        Imam                        -I 2c 2',&
    'x,y,z',&
    '-x,-y,z+1/2',&
    'x,-y,-z',&
    '-x,y,-z+1/2',&
    '-x,-y,-z',&
    'x,y,-z+1/2',&
    '-x,y,z',&
    'x,-y,z+1/2',&
    '',&
    '* 75        C4^1          P4                           P 4',&
    'x,y,z',&
    '-y,x,z',&
    '-x,-y,z',&
    'y,-x,z',&
    '',&
    '* 76        C4^2          P41                          P 4w',&
    'x,y,z',&
    '-y,x,z+1/4',&
    '-x,-y,z+1/2',&
    'y,-x,z+3/4',&
    '',&
    '* 77        C4^3          P42                          P 4c',&
    'x,y,z',&
    '-y,x,z+1/2',&
    '-x,-y,z',&
    'y,-x,z+1/2',&
    '',&
    '* 78        C4^4          P43                          P 4cw',&
    'x,y,z',&
    '-y,x,z+3/4',&
    '-x,-y,z+1/2',&
    'y,-x,z+1/4',&
    '',&
    '* 79        C4^5          I4                           I 4',&
    'x,y,z',&
    '-y,x,z',&
    '-x,-y,z',&
    'y,-x,z',&
    '',&
    '* 80        C4^6          I41                          I 4bw',&
    'x,y,z',&
    '-y,x+1/2,z+1/4',&
    '-x,-y,z',&
    'y,-x+1/2,z+1/4',&
    '',&
    '* 81        S4^1          P-4                          P -4',&
    'x,y,z',&
    'y,-x,-z',&
    '-x,-y,z',&
    '-y,x,-z',&
    '',&
    '* 82        S4^2          I-4                          I -4',&
    'x,y,z',&
    'y,-x,-z',&
    '-x,-y,z',&
    '-y,x,-z',&
    '',&
    '* 83        C4h^1         P4/m                        -P 4',&
    'x,y,z',&
    '-y,x,z',&
    '-x,-y,z',&
    'y,-x,z',&
    '-x,-y,-z',&
    'y,-x,-z',&
    'x,y,-z',&
    '-y,x,-z',&
    '',&
    '* 84        C4h^2         P42/m                       -P 4c',&
    'x,y,z',&
    '-y,x,z+1/2',&
    '-x,-y,z',&
    'y,-x,z+1/2',&
    '-x,-y,-z',&
    'y,-x,-z+1/2',&
    'x,y,-z',&
    '-y,x,-z+1/2',&
    '',&
    '* 85:1      C4h^3         P4/n:1                       P 4ab -1ab',&
    'x,y,z',&
    '-x+1/2,-y+1/2,-z',&
    '-y+1/2,x+1/2,z',&
    '-x,-y,z',&
    'y+1/2,-x+1/2,z',&
    'y,-x,-z',&
    '-y,x,-z',&
    'x+1/2,y+1/2,-z',&
    '',&
    '* 85:2      C4h^3         P4/n:2                      -P 4a',&
    'x,y,z',&
    '-y+1/2,x,z',&
    '-x+1/2,-y+1/2,z',&
    'y,-x+1/2,z',&
    '-x,-y,-z',&
    'y+1/2,-x,-z',&
    'x+1/2,y+1/2,-z',&
    '-y,x+1/2,-z',&
    '',&
    '* 86:1      C4h^4         P42/n:1                      P 4n -1n',&
    'x,y,z',&
    '-x+1/2,-y+1/2,-z+1/2',&
    '-y+1/2,x+1/2,z+1/2',&
    '-x,-y,z',&
    'y+1/2,-x+1/2,z+1/2',&
    'y,-x,-z',&
    '-y,x,-z',&
    'x+1/2,y+1/2,-z+1/2',&
    '',&
    '* 86:2      C4h^4         P42/n:2                     -P 4bc',&
    'x,y,z',&
    '-y,x+1/2,z+1/2',&
    '-x+1/2,-y+1/2,z',&
    'y+1/2,-x,z+1/2',&
    '-x,-y,-z',&
    'y,-x+1/2,-z+1/2',&
    'x+1/2,y+1/2,-z',&
    '-y+1/2,x,-z+1/2',&
    '',&
    '* 87        C4h^5         I4/m                        -I 4',&
    'x,y,z',&
    '-y,x,z',&
    '-x,-y,z',&
    'y,-x,z',&
    '-x,-y,-z',&
    'y,-x,-z',&
    'x,y,-z',&
    '-y,x,-z',&
    '',&
    '* 88:1      C4h^6         I41/a:1                      I 4bw -1bw',&
    'x,y,z',&
    '-x,-y+1/2,-z+1/4',&
    '-y,x+1/2,z+1/4',&
    '-x,-y,z',&
    'y,-x+1/2,z+1/4',&
    'y,-x,-z',&
    '-y,x,-z',&
    'x,y+1/2,-z+1/4',&
    '',&
    '* 88:2      C4h^6         I41/a:2                     -I 4ad',&
    'x,y,z',&
    '-y+3/4,x+1/4,z+1/4',&
    '-x,-y+1/2,z',&
    'y+1/4,-x+1/4,z+1/4',&
    '-x,-y,-z',&
    'y+1/4,-x+3/4,-z+3/4',&
    'x,y+1/2,-z',&
    '-y+3/4,x+3/4,-z+3/4',&
    '',&
    '* 89        D4^1          P422                         P 4 2',&
    'x,y,z',&
    '-y,x,z',&
    '-x,-y,z',&
    'y,-x,z',&
    'x,-y,-z',&
    '-x,y,-z',&
    'y,x,-z',&
    '-y,-x,-z',&
    '',&
    '* 90        D4^2          P4212                        P 4ab 2ab',&
    'x,y,z',&
    '-y+1/2,x+1/2,z',&
    '-x,-y,z',&
    'y+1/2,-x+1/2,z',&
    'x+1/2,-y+1/2,-z',&
    '-x+1/2,y+1/2,-z',&
    'y,x,-z',&
    '-y,-x,-z',&
    '',&
    '* 91        D4^3          P4122                        P 4w 2c',&
    'x,y,z',&
    '-y,x,z+1/4',&
    '-x,-y,z+1/2',&
    'y,-x,z+3/4',&
    'x,-y,-z+1/2',&
    '-x,y,-z',&
    'y,x,-z+3/4',&
    '-y,-x,-z+1/4',&
    '',&
    '* 92        D4^4          P41212                       P 4abw 2nw',&
    'x,y,z',&
    '-y+1/2,x+1/2,z+1/4',&
    '-x,-y,z+1/2',&
    'y+1/2,-x+1/2,z+3/4',&
    'x+1/2,-y+1/2,-z+3/4',&
    '-x+1/2,y+1/2,-z+1/4',&
    'y,x,-z',&
    '-y,-x,-z+1/2',&
    '',&
    '* 93        D4^5          P4222                        P 4c 2',&
    'x,y,z',&
    '-y,x,z+1/2',&
    '-x,-y,z',&
    'y,-x,z+1/2',&
    'x,-y,-z',&
    '-x,y,-z',&
    'y,x,-z+1/2',&
    '-y,-x,-z+1/2',&
    '',&
    '* 94        D4^6          P42212                       P 4n 2n',&
    'x,y,z',&
    '-y+1/2,x+1/2,z+1/2',&
    '-x,-y,z',&
    'y+1/2,-x+1/2,z+1/2',&
    'x+1/2,-y+1/2,-z+1/2',&
    '-x+1/2,y+1/2,-z+1/2',&
    'y,x,-z',&
    '-y,-x,-z',&
    '',&
    '* 95        D4^7          P4322                        P 4cw 2c',&
    'x,y,z',&
    '-y,x,z+3/4',&
    '-x,-y,z+1/2',&
    'y,-x,z+1/4',&
    'x,-y,-z+1/2',&
    '-x,y,-z',&
    'y,x,-z+1/4',&
    '-y,-x,-z+3/4',&
    '',&
    '* 96        D4^8          P43212                       P 4nw 2abw',&
    'x,y,z',&
    '-y+1/2,x+1/2,z+3/4',&
    '-x,-y,z+1/2',&
    'y+1/2,-x+1/2,z+1/4',&
    'x+1/2,-y+1/2,-z+1/4',&
    '-x+1/2,y+1/2,-z+3/4',&
    'y,x,-z',&
    '-y,-x,-z+1/2',&
    '',&
    '* 97        D4^9          I422                         I 4 2',&
    'x,y,z',&
    '-y,x,z',&
    '-x,-y,z',&
    'y,-x,z',&
    'x,-y,-z',&
    '-x,y,-z',&
    'y,x,-z',&
    '-y,-x,-z',&
    '',&
    '* 98        D4^10         I4122                        I 4bw 2bw',&
    'x,y,z',&
    '-y,x+1/2,z+1/4',&
    '-x,-y,z',&
    'y,-x+1/2,z+1/4',&
    'x,-y+1/2,-z+1/4',&
    '-x,y+1/2,-z+1/4',&
    'y,x,-z',&
    '-y,-x,-z',&
    '',&
    '* 99        C4v^1         P4mm                         P 4 -2',&
    'x,y,z',&
    '-y,x,z',&
    '-x,-y,z',&
    'y,-x,z',&
    '-x,y,z',&
    'x,-y,z',&
    '-y,-x,z',&
    'y,x,z',&
    '',&
    '*100        C4v^2         P4bm                         P 4 -2ab',&
    'x,y,z',&
    '-y,x,z',&
    '-x,-y,z',&
    'y,-x,z',&
    '-x+1/2,y+1/2,z',&
    'x+1/2,-y+1/2,z',&
    '-y+1/2,-x+1/2,z',&
    'y+1/2,x+1/2,z',&
    '',&
    '*101        C4v^3         P42cm                        P 4c -2c',&
    'x,y,z',&
    '-y,x,z+1/2',&
    '-x,-y,z',&
    'y,-x,z+1/2',&
    '-x,y,z+1/2',&
    'x,-y,z+1/2',&
    '-y,-x,z',&
    'y,x,z',&
    '',&
    '*102        C4v^4         P42nm                        P 4n -2n',&
    'x,y,z',&
    '-y+1/2,x+1/2,z+1/2',&
    '-x,-y,z',&
    'y+1/2,-x+1/2,z+1/2',&
    '-x+1/2,y+1/2,z+1/2',&
    'x+1/2,-y+1/2,z+1/2',&
    '-y,-x,z',&
    'y,x,z',&
    '',&
    '*103        C4v^5         P4cc                         P 4 -2c',&
    'x,y,z',&
    '-y,x,z',&
    '-x,-y,z',&
    'y,-x,z',&
    '-x,y,z+1/2',&
    'x,-y,z+1/2',&
    '-y,-x,z+1/2',&
    'y,x,z+1/2',&
    '',&
    '*104        C4v^6         P4nc                         P 4 -2n',&
    'x,y,z',&
    '-y,x,z',&
    '-x,-y,z',&
    'y,-x,z',&
    '-x+1/2,y+1/2,z+1/2',&
    'x+1/2,-y+1/2,z+1/2',&
    '-y+1/2,-x+1/2,z+1/2',&
    'y+1/2,x+1/2,z+1/2',&
    '',&
    '*105        C4v^7         P42mc                        P 4c -2',&
    'x,y,z',&
    '-y,x,z+1/2',&
    '-x,-y,z',&
    'y,-x,z+1/2',&
    '-x,y,z',&
    'x,-y,z',&
    '-y,-x,z+1/2',&
    'y,x,z+1/2',&
    '',&
    '*106        C4v^8         P42bc                        P 4c -2ab',&
    'x,y,z',&
    '-y,x,z+1/2',&
    '-x,-y,z',&
    'y,-x,z+1/2',&
    '-x+1/2,y+1/2,z',&
    'x+1/2,-y+1/2,z',&
    '-y+1/2,-x+1/2,z+1/2',&
    'y+1/2,x+1/2,z+1/2',&
    '',&
    '*107        C4v^9         I4mm                         I 4 -2',&
    'x,y,z',&
    '-y,x,z',&
    '-x,-y,z',&
    'y,-x,z',&
    '-x,y,z',&
    'x,-y,z',&
    '-y,-x,z',&
    'y,x,z',&
    '',&
    '*108        C4v^10        I4cm                         I 4 -2c',&
    'x,y,z',&
    '-y,x,z',&
    '-x,-y,z',&
    'y,-x,z',&
    '-x,y,z+1/2',&
    'x,-y,z+1/2',&
    '-y,-x,z+1/2',&
    'y,x,z+1/2',&
    '',&
    '*109        C4v^11        I41md                        I 4bw -2',&
    'x,y,z',&
    '-y,x+1/2,z+1/4',&
    '-x,-y,z',&
    'y,-x+1/2,z+1/4',&
    '-x,y,z',&
    'x,-y,z',&
    '-y,-x+1/2,z+1/4',&
    'y,x+1/2,z+1/4',&
    '',&
    '*110        C4v^12        I41cd                        I 4bw -2c',&
    'x,y,z',&
    '-y,x+1/2,z+1/4',&
    '-x,-y,z',&
    'y,-x+1/2,z+1/4',&
    '-x,y,z+1/2',&
    'x,-y,z+1/2',&
    '-y+1/2,-x,z+1/4',&
    'y+1/2,x,z+1/4',&
    '',&
    '*111        D2d^1         P-42m                        P -4 2',&
    'x,y,z',&
    'y,-x,-z',&
    '-x,-y,z',&
    '-y,x,-z',&
    'x,-y,-z',&
    '-x,y,-z',&
    '-y,-x,z',&
    'y,x,z',&
    '',&
    '*112        D2d^2         P-42c                        P -4 2c',&
    'x,y,z',&
    'y,-x,-z',&
    '-x,-y,z',&
    '-y,x,-z',&
    'x,-y,-z+1/2',&
    '-x,y,-z+1/2',&
    '-y,-x,z+1/2',&
    'y,x,z+1/2',&
    '',&
    '*113        D2d^3         P-421m                       P -4 2ab',&
    'x,y,z',&
    'y,-x,-z',&
    '-x,-y,z',&
    '-y,x,-z',&
    'x+1/2,-y+1/2,-z',&
    '-x+1/2,y+1/2,-z',&
    '-y+1/2,-x+1/2,z',&
    'y+1/2,x+1/2,z',&
    '',&
    '*114        D2d^4         P-421c                       P -4 2n',&
    'x,y,z',&
    'y,-x,-z',&
    '-x,-y,z',&
    '-y,x,-z',&
    'x+1/2,-y+1/2,-z+1/2',&
    '-x+1/2,y+1/2,-z+1/2',&
    '-y+1/2,-x+1/2,z+1/2',&
    'y+1/2,x+1/2,z+1/2',&
    '',&
    '*115        D2d^5         P-4m2                        P -4 -2',&
    'x,y,z',&
    'y,-x,-z',&
    '-x,-y,z',&
    '-y,x,-z',&
    'y,x,-z',&
    '-y,-x,-z',&
    '-x,y,z',&
    'x,-y,z',&
    '',&
    '*116        D2d^6         P-4c2                        P -4 -2c',&
    'x,y,z',&
    'y,-x,-z',&
    '-x,-y,z',&
    '-y,x,-z',&
    'y,x,-z+1/2',&
    '-y,-x,-z+1/2',&
    '-x,y,z+1/2',&
    'x,-y,z+1/2',&
    '',&
    '*117        D2d^7         P-4b2                        P -4 -2ab',&
    'x,y,z',&
    'y,-x,-z',&
    '-x,-y,z',&
    '-y,x,-z',&
    'y+1/2,x+1/2,-z',&
    '-y+1/2,-x+1/2,-z',&
    '-x+1/2,y+1/2,z',&
    'x+1/2,-y+1/2,z',&
    '',&
    '*118        D2d^8         P-4n2                        P -4 -2n',&
    'x,y,z',&
    'y,-x,-z',&
    '-x,-y,z',&
    '-y,x,-z',&
    'y+1/2,x+1/2,-z+1/2',&
    '-y+1/2,-x+1/2,-z+1/2',&
    '-x+1/2,y+1/2,z+1/2',&
    'x+1/2,-y+1/2,z+1/2',&
    '',&
    '*119        D2d^9         I-4m2                        I -4 -2',&
    'x,y,z',&
    'y,-x,-z',&
    '-x,-y,z',&
    '-y,x,-z',&
    'y,x,-z',&
    '-y,-x,-z',&
    '-x,y,z',&
    'x,-y,z',&
    '',&
    '*120        D2d^10        I-4c2                        I -4 -2c',&
    'x,y,z',&
    'y,-x,-z',&
    '-x,-y,z',&
    '-y,x,-z',&
    'y,x,-z+1/2',&
    '-y,-x,-z+1/2',&
    '-x,y,z+1/2',&
    'x,-y,z+1/2',&
    '',&
    '*121        D2d^11        I-42m                        I -4 2',&
    'x,y,z',&
    'y,-x,-z',&
    '-x,-y,z',&
    '-y,x,-z',&
    'x,-y,-z',&
    '-x,y,-z',&
    '-y,-x,z',&
    'y,x,z',&
    '',&
    '*122        D2d^12        I-42d                        I -4 2bw',&
    'x,y,z',&
    'y,-x,-z',&
    '-x,-y,z',&
    '-y,x,-z',&
    'x,-y+1/2,-z+1/4',&
    '-x,y+1/2,-z+1/4',&
    '-y,-x+1/2,z+1/4',&
    'y,x+1/2,z+1/4',&
    '',&
    '*123        D4h^1         P4/mmm                      -P 4 2',&
    'x,y,z',&
    '-y,x,z',&
    '-x,-y,z',&
    'y,-x,z',&
    'x,-y,-z',&
    '-x,y,-z',&
    'y,x,-z',&
    '-y,-x,-z',&
    '-x,-y,-z',&
    'y,-x,-z',&
    'x,y,-z',&
    '-y,x,-z',&
    '-x,y,z',&
    'x,-y,z',&
    '-y,-x,z',&
    'y,x,z',&
    '',&
    '*124        D4h^2         P4/mcc                      -P 4 2c',&
    'x,y,z',&
    '-y,x,z',&
    '-x,-y,z',&
    'y,-x,z',&
    'x,-y,-z+1/2',&
    '-x,y,-z+1/2',&
    'y,x,-z+1/2',&
    '-y,-x,-z+1/2',&
    '-x,-y,-z',&
    'y,-x,-z',&
    'x,y,-z',&
    '-y,x,-z',&
    '-x,y,z+1/2',&
    'x,-y,z+1/2',&
    '-y,-x,z+1/2',&
    'y,x,z+1/2',&
    '',&
    '*125:1      D4h^3         P4/nbm:1                     P 4 2 -1ab',&
    'x,y,z',&
    '-x+1/2,-y+1/2,-z',&
    '-y,x,z',&
    '-x,-y,z',&
    'y,-x,z',&
    'y+1/2,-x+1/2,-z',&
    '-y+1/2,x+1/2,-z',&
    'x,-y,-z',&
    '-x,y,-z',&
    'y,x,-z',&
    '-y,-x,-z',&
    'x+1/2,y+1/2,-z',&
    '-x+1/2,y+1/2,z',&
    'x+1/2,-y+1/2,z',&
    '-y+1/2,-x+1/2,z',&
    'y+1/2,x+1/2,z',&
    '',&
    '*125:2      D4h^3         P4/nbm:2                    -P 4a 2b',&
    'x,y,z',&
    '-y+1/2,x,z',&
    '-x+1/2,-y+1/2,z',&
    'y,-x+1/2,z',&
    'x,-y+1/2,-z',&
    '-x+1/2,y,-z',&
    'y,x,-z',&
    '-y+1/2,-x+1/2,-z',&
    '-x,-y,-z',&
    'y+1/2,-x,-z',&
    'x+1/2,y+1/2,-z',&
    '-y,x+1/2,-z',&
    '-x,y+1/2,z',&
    'x+1/2,-y,z',&
    '-y,-x,z',&
    'y+1/2,x+1/2,z',&
    '',&
    '*126:1      D4h^4         P4/nnc:1                     P 4 2 -1n',&
    'x,y,z',&
    '-x+1/2,-y+1/2,-z+1/2',&
    '-y,x,z',&
    '-x,-y,z',&
    'y,-x,z',&
    'y+1/2,-x+1/2,-z+1/2',&
    '-y+1/2,x+1/2,-z+1/2',&
    'x,-y,-z',&
    '-x,y,-z',&
    'y,x,-z',&
    '-y,-x,-z',&
    'x+1/2,y+1/2,-z+1/2',&
    '-x+1/2,y+1/2,z+1/2',&
    'x+1/2,-y+1/2,z+1/2',&
    '-y+1/2,-x+1/2,z+1/2',&
    'y+1/2,x+1/2,z+1/2',&
    '',&
    '*126:2      D4h^4         P4/nnc:2                    -P 4a 2bc',&
    'x,y,z',&
    '-y+1/2,x,z',&
    '-x+1/2,-y+1/2,z',&
    'y,-x+1/2,z',&
    'x,-y+1/2,-z+1/2',&
    '-x+1/2,y,-z+1/2',&
    'y,x,-z+1/2',&
    '-y+1/2,-x+1/2,-z+1/2',&
    '-x,-y,-z',&
    'y+1/2,-x,-z',&
    'x+1/2,y+1/2,-z',&
    '-y,x+1/2,-z',&
    '-x,y+1/2,z+1/2',&
    'x+1/2,-y,z+1/2',&
    '-y,-x,z+1/2',&
    'y+1/2,x+1/2,z+1/2',&
    '',&
    '*127        D4h^5         P4/mbm                      -P 4 2ab',&
    'x,y,z',&
    '-y,x,z',&
    '-x,-y,z',&
    'y,-x,z',&
    'x+1/2,-y+1/2,-z',&
    '-x+1/2,y+1/2,-z',&
    'y+1/2,x+1/2,-z',&
    '-y+1/2,-x+1/2,-z',&
    '-x,-y,-z',&
    'y,-x,-z',&
    'x,y,-z',&
    '-y,x,-z',&
    '-x+1/2,y+1/2,z',&
    'x+1/2,-y+1/2,z',&
    '-y+1/2,-x+1/2,z',&
    'y+1/2,x+1/2,z',&
    '',&
    '*128        D4h^6         P4/mnc                      -P 4 2n',&
    'x,y,z',&
    '-y,x,z',&
    '-x,-y,z',&
    'y,-x,z',&
    'x+1/2,-y+1/2,-z+1/2',&
    '-x+1/2,y+1/2,-z+1/2',&
    'y+1/2,x+1/2,-z+1/2',&
    '-y+1/2,-x+1/2,-z+1/2',&
    '-x,-y,-z',&
    'y,-x,-z',&
    'x,y,-z',&
    '-y,x,-z',&
    '-x+1/2,y+1/2,z+1/2',&
    'x+1/2,-y+1/2,z+1/2',&
    '-y+1/2,-x+1/2,z+1/2',&
    'y+1/2,x+1/2,z+1/2',&
    '',&
    '*129:1      D4h^7         P4/nmm:1                     P 4ab 2ab -1ab',&
    'x,y,z',&
    '-x+1/2,-y+1/2,-z',&
    '-y+1/2,x+1/2,z',&
    '-x,-y,z',&
    'y+1/2,-x+1/2,z',&
    'y,-x,-z',&
    '-y,x,-z',&
    'x+1/2,-y+1/2,-z',&
    '-x+1/2,y+1/2,-z',&
    'y,x,-z',&
    '-y,-x,-z',&
    'x+1/2,y+1/2,-z',&
    '-x,y,z',&
    'x,-y,z',&
    '-y+1/2,-x+1/2,z',&
    'y+1/2,x+1/2,z',&
    '',&
    '*129:2      D4h^7         P4/nmm:2                    -P 4a 2a',&
    'x,y,z',&
    '-y+1/2,x,z',&
    '-x+1/2,-y+1/2,z',&
    'y,-x+1/2,z',&
    'x+1/2,-y,-z',&
    '-x,y+1/2,-z',&
    'y+1/2,x+1/2,-z',&
    '-y,-x,-z',&
    '-x,-y,-z',&
    'y+1/2,-x,-z',&
    'x+1/2,y+1/2,-z',&
    '-y,x+1/2,-z',&
    '-x+1/2,y,z',&
    'x,-y+1/2,z',&
    '-y+1/2,-x+1/2,z',&
    'y,x,z',&
    '',&
    '*130:1      D4h^8         P4/ncc:1                     P 4ab 2n -1ab',&
    'x,y,z',&
    '-x+1/2,-y+1/2,-z',&
    '-y+1/2,x+1/2,z',&
    '-x,-y,z',&
    'y+1/2,-x+1/2,z',&
    'y,-x,-z',&
    '-y,x,-z',&
    'x+1/2,-y+1/2,-z+1/2',&
    '-x+1/2,y+1/2,-z+1/2',&
    'y,x,-z+1/2',&
    '-y,-x,-z+1/2',&
    'x+1/2,y+1/2,-z',&
    '-x,y,z+1/2',&
    'x,-y,z+1/2',&
    '-y+1/2,-x+1/2,z+1/2',&
    'y+1/2,x+1/2,z+1/2',&
    '',&
    '*130:2      D4h^8         P4/ncc:2                    -P 4a 2ac',&
    'x,y,z',&
    '-y+1/2,x,z',&
    '-x+1/2,-y+1/2,z',&
    'y,-x+1/2,z',&
    'x+1/2,-y,-z+1/2',&
    '-x,y+1/2,-z+1/2',&
    'y+1/2,x+1/2,-z+1/2',&
    '-y,-x,-z+1/2',&
    '-x,-y,-z',&
    'y+1/2,-x,-z',&
    'x+1/2,y+1/2,-z',&
    '-y,x+1/2,-z',&
    '-x+1/2,y,z+1/2',&
    'x,-y+1/2,z+1/2',&
    '-y+1/2,-x+1/2,z+1/2',&
    'y,x,z+1/2',&
    '',&
    '*131        D4h^9         P42/mmc                     -P 4c 2',&
    'x,y,z',&
    '-y,x,z+1/2',&
    '-x,-y,z',&
    'y,-x,z+1/2',&
    'x,-y,-z',&
    '-x,y,-z',&
    'y,x,-z+1/2',&
    '-y,-x,-z+1/2',&
    '-x,-y,-z',&
    'y,-x,-z+1/2',&
    'x,y,-z',&
    '-y,x,-z+1/2',&
    '-x,y,z',&
    'x,-y,z',&
    '-y,-x,z+1/2',&
    'y,x,z+1/2',&
    '',&
    '*132        D4h^10        P42/mcm                     -P 4c 2c',&
    'x,y,z',&
    '-y,x,z+1/2',&
    '-x,-y,z',&
    'y,-x,z+1/2',&
    'x,-y,-z+1/2',&
    '-x,y,-z+1/2',&
    'y,x,-z',&
    '-y,-x,-z',&
    '-x,-y,-z',&
    'y,-x,-z+1/2',&
    'x,y,-z',&
    '-y,x,-z+1/2',&
    '-x,y,z+1/2',&
    'x,-y,z+1/2',&
    '-y,-x,z',&
    'y,x,z',&
    '',&
    '*133:1      D4h^11        P42/nbc:1                    P 4n 2c -1n',&
    'x,y,z',&
    '-x+1/2,-y+1/2,-z+1/2',&
    '-y+1/2,x+1/2,z+1/2',&
    '-x,-y,z',&
    'y+1/2,-x+1/2,z+1/2',&
    'y,-x,-z',&
    '-y,x,-z',&
    'x,-y,-z+1/2',&
    '-x,y,-z+1/2',&
    'y+1/2,x+1/2,-z',&
    '-y+1/2,-x+1/2,-z',&
    'x+1/2,y+1/2,-z+1/2',&
    '-x+1/2,y+1/2,z',&
    'x+1/2,-y+1/2,z',&
    '-y,-x,z+1/2',&
    'y,x,z+1/2',&
    '',&
    '*133:2      D4h^11        P42/nbc:2                   -P 4ac 2b',&
    'x,y,z',&
    '-y+1/2,x,z+1/2',&
    '-x+1/2,-y+1/2,z',&
    'y,-x+1/2,z+1/2',&
    'x,-y+1/2,-z',&
    '-x+1/2,y,-z',&
    'y,x,-z+1/2',&
    '-y+1/2,-x+1/2,-z+1/2',&
    '-x,-y,-z',&
    'y+1/2,-x,-z+1/2',&
    'x+1/2,y+1/2,-z',&
    '-y,x+1/2,-z+1/2',&
    '-x,y+1/2,z',&
    'x+1/2,-y,z',&
    '-y,-x,z+1/2',&
    'y+1/2,x+1/2,z+1/2',&
    '',&
    '*134:1      D4h^12        P42/nnm:1                    P 4n 2 -1n',&
    'x,y,z',&
    '-x+1/2,-y+1/2,-z+1/2',&
    '-y+1/2,x+1/2,z+1/2',&
    '-x,-y,z',&
    'y+1/2,-x+1/2,z+1/2',&
    'y,-x,-z',&
    '-y,x,-z',&
    'x,-y,-z',&
    '-x,y,-z',&
    'y+1/2,x+1/2,-z+1/2',&
    '-y+1/2,-x+1/2,-z+1/2',&
    'x+1/2,y+1/2,-z+1/2',&
    '-x+1/2,y+1/2,z+1/2',&
    'x+1/2,-y+1/2,z+1/2',&
    '-y,-x,z',&
    'y,x,z',&
    '',&
    '*134:2      D4h^12        P42/nnm:2                   -P 4ac 2bc',&
    'x,y,z',&
    '-y+1/2,x,z+1/2',&
    '-x+1/2,-y+1/2,z',&
    'y,-x+1/2,z+1/2',&
    'x,-y+1/2,-z+1/2',&
    '-x+1/2,y,-z+1/2',&
    'y,x,-z',&
    '-y+1/2,-x+1/2,-z',&
    '-x,-y,-z',&
    'y+1/2,-x,-z+1/2',&
    'x+1/2,y+1/2,-z',&
    '-y,x+1/2,-z+1/2',&
    '-x,y+1/2,z+1/2',&
    'x+1/2,-y,z+1/2',&
    '-y,-x,z',&
    'y+1/2,x+1/2,z',&
    '',&
    '*135        D4h^13        P42/mbc                     -P 4c 2ab',&
    'x,y,z',&
    '-y,x,z+1/2',&
    '-x,-y,z',&
    'y,-x,z+1/2',&
    'x+1/2,-y+1/2,-z',&
    '-x+1/2,y+1/2,-z',&
    'y+1/2,x+1/2,-z+1/2',&
    '-y+1/2,-x+1/2,-z+1/2',&
    '-x,-y,-z',&
    'y,-x,-z+1/2',&
    'x,y,-z',&
    '-y,x,-z+1/2',&
    '-x+1/2,y+1/2,z',&
    'x+1/2,-y+1/2,z',&
    '-y+1/2,-x+1/2,z+1/2',&
    'y+1/2,x+1/2,z+1/2',&
    '',&
    '*136        D4h^14        P42/mnm                     -P 4n 2n',&
    'x,y,z',&
    '-y+1/2,x+1/2,z+1/2',&
    '-x,-y,z',&
    'y+1/2,-x+1/2,z+1/2',&
    'x+1/2,-y+1/2,-z+1/2',&
    '-x+1/2,y+1/2,-z+1/2',&
    'y,x,-z',&
    '-y,-x,-z',&
    '-x,-y,-z',&
    'y+1/2,-x+1/2,-z+1/2',&
    'x,y,-z',&
    '-y+1/2,x+1/2,-z+1/2',&
    '-x+1/2,y+1/2,z+1/2',&
    'x+1/2,-y+1/2,z+1/2',&
    '-y,-x,z',&
    'y,x,z',&
    '',&
    '*137:1      D4h^15        P42/nmc:1                    P 4n 2n -1n',&
    'x,y,z',&
    '-x+1/2,-y+1/2,-z+1/2',&
    '-y+1/2,x+1/2,z+1/2',&
    '-x,-y,z',&
    'y+1/2,-x+1/2,z+1/2',&
    'y,-x,-z',&
    '-y,x,-z',&
    'x+1/2,-y+1/2,-z+1/2',&
    '-x+1/2,y+1/2,-z+1/2',&
    'y,x,-z',&
    '-y,-x,-z',&
    'x+1/2,y+1/2,-z+1/2',&
    '-x,y,z',&
    'x,-y,z',&
    '-y+1/2,-x+1/2,z+1/2',&
    'y+1/2,x+1/2,z+1/2',&
    '',&
    '*137:2      D4h^15        P42/nmc:2                   -P 4ac 2a',&
    'x,y,z',&
    '-y+1/2,x,z+1/2',&
    '-x+1/2,-y+1/2,z',&
    'y,-x+1/2,z+1/2',&
    'x+1/2,-y,-z',&
    '-x,y+1/2,-z',&
    'y+1/2,x+1/2,-z+1/2',&
    '-y,-x,-z+1/2',&
    '-x,-y,-z',&
    'y+1/2,-x,-z+1/2',&
    'x+1/2,y+1/2,-z',&
    '-y,x+1/2,-z+1/2',&
    '-x+1/2,y,z',&
    'x,-y+1/2,z',&
    '-y+1/2,-x+1/2,z+1/2',&
    'y,x,z+1/2',&
    '',&
    '*138:1      D4h^16        P42/ncm:1                    P 4n 2ab -1n',&
    'x,y,z',&
    '-x+1/2,-y+1/2,-z+1/2',&
    '-y+1/2,x+1/2,z+1/2',&
    '-x,-y,z',&
    'y+1/2,-x+1/2,z+1/2',&
    'y,-x,-z',&
    '-y,x,-z',&
    'x+1/2,-y+1/2,-z',&
    '-x+1/2,y+1/2,-z',&
    'y,x,-z+1/2',&
    '-y,-x,-z+1/2',&
    'x+1/2,y+1/2,-z+1/2',&
    '-x,y,z+1/2',&
    'x,-y,z+1/2',&
    '-y+1/2,-x+1/2,z',&
    'y+1/2,x+1/2,z',&
    '',&
    '*138:2      D4h^16        P42/ncm:2                   -P 4ac 2ac',&
    'x,y,z',&
    '-y+1/2,x,z+1/2',&
    '-x+1/2,-y+1/2,z',&
    'y,-x+1/2,z+1/2',&
    'x+1/2,-y,-z+1/2',&
    '-x,y+1/2,-z+1/2',&
    'y+1/2,x+1/2,-z',&
    '-y,-x,-z',&
    '-x,-y,-z',&
    'y+1/2,-x,-z+1/2',&
    'x+1/2,y+1/2,-z',&
    '-y,x+1/2,-z+1/2',&
    '-x+1/2,y,z+1/2',&
    'x,-y+1/2,z+1/2',&
    '-y+1/2,-x+1/2,z',&
    'y,x,z',&
    '',&
    '*139        D4h^17        I4/mmm                      -I 4 2',&
    'x,y,z',&
    '-y,x,z',&
    '-x,-y,z',&
    'y,-x,z',&
    'x,-y,-z',&
    '-x,y,-z',&
    'y,x,-z',&
    '-y,-x,-z',&
    '-x,-y,-z',&
    'y,-x,-z',&
    'x,y,-z',&
    '-y,x,-z',&
    '-x,y,z',&
    'x,-y,z',&
    '-y,-x,z',&
    'y,x,z',&
    '',&
    '*140        D4h^18        I4/mcm                      -I 4 2c',&
    'x,y,z',&
    '-y,x,z',&
    '-x,-y,z',&
    'y,-x,z',&
    'x,-y,-z+1/2',&
    '-x,y,-z+1/2',&
    'y,x,-z+1/2',&
    '-y,-x,-z+1/2',&
    '-x,-y,-z',&
    'y,-x,-z',&
    'x,y,-z',&
    '-y,x,-z',&
    '-x,y,z+1/2',&
    'x,-y,z+1/2',&
    '-y,-x,z+1/2',&
    'y,x,z+1/2',&
    '',&
    '*141:1      D4h^19        I41/amd:1                    I 4bw 2bw -1bw',&
    'x,y,z',&
    '-x,-y+1/2,-z+1/4',&
    '-y,x+1/2,z+1/4',&
    '-x,-y,z',&
    'y,-x+1/2,z+1/4',&
    'y,-x,-z',&
    '-y,x,-z',&
    'x,-y+1/2,-z+1/4',&
    '-x,y+1/2,-z+1/4',&
    'y,x,-z',&
    '-y,-x,-z',&
    'x,y+1/2,-z+1/4',&
    '-x,y,z',&
    'x,-y,z',&
    '-y,-x+1/2,z+1/4',&
    'y,x+1/2,z+1/4',&
    '',&
    '*141:2      D4h^19        I41/amd:2                   -I 4bd 2',&
    'x,y,z',&
    '-y+1/4,x+3/4,z+1/4',&
    '-x,-y+1/2,z',&
    'y+1/4,-x+1/4,z+3/4',&
    'x,-y,-z',&
    '-x,y+1/2,-z',&
    'y+1/4,x+3/4,-z+1/4',&
    '-y+1/4,-x+1/4,-z+3/4',&
    '-x,-y,-z',&
    'y+3/4,-x+1/4,-z+3/4',&
    'x,y+1/2,-z',&
    '-y+3/4,x+3/4,-z+1/4',&
    '-x,y,z',&
    'x,-y+1/2,z',&
    '-y+3/4,-x+1/4,z+3/4',&
    'y+3/4,x+3/4,z+1/4',&
    '',&
    '*142:1      D4h^20        I41/acd:1                    I 4bw 2aw -1bw',&
    'x,y,z',&
    '-x,-y+1/2,-z+1/4',&
    '-y,x+1/2,z+1/4',&
    '-x,-y,z',&
    'y,-x+1/2,z+1/4',&
    'y,-x,-z',&
    '-y,x,-z',&
    'x+1/2,-y,-z+1/4',&
    '-x+1/2,y,-z+1/4',&
    'y,x,-z+1/2',&
    '-y,-x,-z+1/2',&
    'x,y+1/2,-z+1/4',&
    '-x,y,z+1/2',&
    'x,-y,z+1/2',&
    '-y+1/2,-x,z+1/4',&
    'y+1/2,x,z+1/4',&
    '',&
    '*142:2      D4h^20        I41/acd:2                   -I 4bd 2c',&
    'x,y,z',&
    '-y+1/4,x+3/4,z+1/4',&
    '-x,-y+1/2,z',&
    'y+1/4,-x+1/4,z+3/4',&
    'x,-y,-z+1/2',&
    '-x+1/2,y,-z',&
    'y+3/4,x+1/4,-z+1/4',&
    '-y+1/4,-x+1/4,-z+1/4',&
    '-x,-y,-z',&
    'y+3/4,-x+1/4,-z+3/4',&
    'x,y+1/2,-z',&
    '-y+3/4,x+3/4,-z+1/4',&
    '-x,y,z+1/2',&
    'x+1/2,-y,z',&
    '-y+1/4,-x+3/4,z+3/4',&
    'y+3/4,x+3/4,z+3/4',&
    '',&
    '*143        C3^1          P3                           P 3',&
    'x,y,z',&
    '-y,x-y,z',&
    '-x+y,-x,z',&
    '',&
    '*144        C3^2          P31                          P 31',&
    'x,y,z',&
    '-y,x-y,z+1/3',&
    '-x+y,-x,z+2/3',&
    '',&
    '*145        C3^3          P32                          P 32',&
    'x,y,z',&
    '-y,x-y,z+2/3',&
    '-x+y,-x,z+1/3',&
    '',&
    '*146:H      C3^4          R3:H                         R 3',&
    'x,y,z',&
    '-y,x-y,z',&
    '-x+y,-x,z',&
    '',&
    '*146:R      C3^4          R3:R                         P 3*',&
    'x,y,z',&
    'z,x,y',&
    'y,z,x',&
    '',&
    '*147        C3i^1         P-3                         -P 3',&
    'x,y,z',&
    '-y,x-y,z',&
    '-x+y,-x,z',&
    '-x,-y,-z',&
    'y,-x+y,-z',&
    'x-y,x,-z',&
    '',&
    '*148:H      C3i^2         R-3:H                       -R 3',&
    'x,y,z',&
    '-y,x-y,z',&
    '-x+y,-x,z',&
    '-x,-y,-z',&
    'y,-x+y,-z',&
    'x-y,x,-z',&
    '',&
    '*148:R      C3i^2         R-3:R                       -P 3*',&
    'x,y,z',&
    'z,x,y',&
    'y,z,x',&
    '-x,-y,-z',&
    '-z,-x,-y',&
    '-y,-z,-x',&
    '',&
    '*149        D3^1          P312                         P 3 2',&
    'x,y,z',&
    '-y,x-y,z',&
    '-x+y,-x,z',&
    '-y,-x,-z',&
    '-x+y,y,-z',&
    'x,x-y,-z',&
    '',&
    '*150        D3^2          P321                         P 3 2"',&
    'x,y,z',&
    '-y,x-y,z',&
    '-x+y,-x,z',&
    'x-y,-y,-z',&
    '-x,-x+y,-z',&
    'y,x,-z',&
    '',&
    '*151        D3^3          P3112                        P 31 2c (0 0 1)',&
    'x,y,z',&
    '-y,x-y,z+1/3',&
    '-x+y,-x,z+2/3',&
    '-y,-x,-z+2/3',&
    '-x+y,y,-z+1/3',&
    'x,x-y,-z',&
    '',&
    '*152        D3^4          P3121                        P 31 2"',&
    'x,y,z',&
    '-y,x-y,z+1/3',&
    '-x+y,-x,z+2/3',&
    'x-y,-y,-z+2/3',&
    '-x,-x+y,-z+1/3',&
    'y,x,-z',&
    '',&
    '*153        D3^5          P3212                        P 32 2c (0 0 -1)',&
    'x,y,z',&
    '-y,x-y,z+2/3',&
    '-x+y,-x,z+1/3',&
    '-y,-x,-z+1/3',&
    '-x+y,y,-z+2/3',&
    'x,x-y,-z',&
    '',&
    '*154        D3^6          P3221                        P 32 2"',&
    'x,y,z',&
    '-y,x-y,z+2/3',&
    '-x+y,-x,z+1/3',&
    'x-y,-y,-z+1/3',&
    '-x,-x+y,-z+2/3',&
    'y,x,-z',&
    '',&
    '*155:H      D3^7          R32:H                        R 3 2"',&
    'x,y,z',&
    '-y,x-y,z',&
    '-x+y,-x,z',&
    'x-y,-y,-z',&
    '-x,-x+y,-z',&
    'y,x,-z',&
    '',&
    '*155:R      D3^7          R32:R                        P 3* 2',&
    'x,y,z',&
    'z,x,y',&
    'y,z,x',&
    '-y,-x,-z',&
    '-x,-z,-y',&
    '-z,-y,-x',&
    '',&
    '*156        C3v^1         P3m1                         P 3 -2"',&
    'x,y,z',&
    '-y,x-y,z',&
    '-x+y,-x,z',&
    '-x+y,y,z',&
    'x,x-y,z',&
    '-y,-x,z',&
    '',&
    '*157        C3v^2         P31m                         P 3 -2',&
    'x,y,z',&
    '-y,x-y,z',&
    '-x+y,-x,z',&
    'y,x,z',&
    'x-y,-y,z',&
    '-x,-x+y,z',&
    '',&
    '*158        C3v^3         P3c1                         P 3 -2"c',&
    'x,y,z',&
    '-y,x-y,z',&
    '-x+y,-x,z',&
    '-x+y,y,z+1/2',&
    'x,x-y,z+1/2',&
    '-y,-x,z+1/2',&
    '',&
    '*159        C3v^4         P31c                         P 3 -2c',&
    'x,y,z',&
    '-y,x-y,z',&
    '-x+y,-x,z',&
    'y,x,z+1/2',&
    'x-y,-y,z+1/2',&
    '-x,-x+y,z+1/2',&
    '',&
    '*160:H      C3v^5         R3m:H                        R 3 -2"',&
    'x,y,z',&
    '-y,x-y,z',&
    '-x+y,-x,z',&
    '-x+y,y,z',&
    'x,x-y,z',&
    '-y,-x,z',&
    '',&
    '*160:R      C3v^5         R3m:R                        P 3* -2',&
    'x,y,z',&
    'z,x,y',&
    'y,z,x',&
    'y,x,z',&
    'x,z,y',&
    'z,y,x',&
    '',&
    '*161:H      C3v^6         R3c:H                        R 3 -2"c',&
    'x,y,z',&
    '-y,x-y,z',&
    '-x+y,-x,z',&
    '-x+y,y,z+1/2',&
    'x,x-y,z+1/2',&
    '-y,-x,z+1/2',&
    '',&
    '*161:R      C3v^6         R3c:R                        P 3* -2n',&
    'x,y,z',&
    'z,x,y',&
    'y,z,x',&
    'y+1/2,x+1/2,z+1/2',&
    'x+1/2,z+1/2,y+1/2',&
    'z+1/2,y+1/2,x+1/2',&
    '',&
    '*162        D3d^1         P-31m                       -P 3 2',&
    'x,y,z',&
    '-y,x-y,z',&
    '-x+y,-x,z',&
    '-y,-x,-z',&
    '-x+y,y,-z',&
    'x,x-y,-z',&
    '-x,-y,-z',&
    'y,-x+y,-z',&
    'x-y,x,-z',&
    'y,x,z',&
    'x-y,-y,z',&
    '-x,-x+y,z',&
    '',&
    '*163        D3d^2         P-31c                       -P 3 2c',&
    'x,y,z',&
    '-y,x-y,z',&
    '-x+y,-x,z',&
    '-y,-x,-z+1/2',&
    '-x+y,y,-z+1/2',&
    'x,x-y,-z+1/2',&
    '-x,-y,-z',&
    'y,-x+y,-z',&
    'x-y,x,-z',&
    'y,x,z+1/2',&
    'x-y,-y,z+1/2',&
    '-x,-x+y,z+1/2',&
    '',&
    '*164        D3d^3         P-3m1                       -P 3 2"',&
    'x,y,z',&
    '-y,x-y,z',&
    '-x+y,-x,z',&
    'x-y,-y,-z',&
    '-x,-x+y,-z',&
    'y,x,-z',&
    '-x,-y,-z',&
    'y,-x+y,-z',&
    'x-y,x,-z',&
    '-x+y,y,z',&
    'x,x-y,z',&
    '-y,-x,z',&
    '',&
    '*165        D3d^4         P-3c1                       -P 3 2"c',&
    'x,y,z',&
    '-y,x-y,z',&
    '-x+y,-x,z',&
    'x-y,-y,-z+1/2',&
    '-x,-x+y,-z+1/2',&
    'y,x,-z+1/2',&
    '-x,-y,-z',&
    'y,-x+y,-z',&
    'x-y,x,-z',&
    '-x+y,y,z+1/2',&
    'x,x-y,z+1/2',&
    '-y,-x,z+1/2',&
    '',&
    '*166:H      D3d^5         R-3m:H                      -R 3 2"',&
    'x,y,z',&
    '-y,x-y,z',&
    '-x+y,-x,z',&
    'x-y,-y,-z',&
    '-x,-x+y,-z',&
    'y,x,-z',&
    '-x,-y,-z',&
    'y,-x+y,-z',&
    'x-y,x,-z',&
    '-x+y,y,z',&
    'x,x-y,z',&
    '-y,-x,z',&
    '',&
    '*166:R      D3d^5         R-3m:R                      -P 3* 2',&
    'x,y,z',&
    'z,x,y',&
    'y,z,x',&
    '-y,-x,-z',&
    '-x,-z,-y',&
    '-z,-y,-x',&
    '-x,-y,-z',&
    '-z,-x,-y',&
    '-y,-z,-x',&
    'y,x,z',&
    'x,z,y',&
    'z,y,x',&
    '',&
    '*167:H      D3d^6         R-3c:H                      -R 3 2"c',&
    'x,y,z',&
    '-y,x-y,z',&
    '-x+y,-x,z',&
    'x-y,-y,-z+1/2',&
    '-x,-x+y,-z+1/2',&
    'y,x,-z+1/2',&
    '-x,-y,-z',&
    'y,-x+y,-z',&
    'x-y,x,-z',&
    '-x+y,y,z+1/2',&
    'x,x-y,z+1/2',&
    '-y,-x,z+1/2',&
    '',&
    '*167:R      D3d^6         R-3c:R                      -P 3* 2n',&
    'x,y,z',&
    'z,x,y',&
    'y,z,x',&
    '-y+1/2,-x+1/2,-z+1/2',&
    '-x+1/2,-z+1/2,-y+1/2',&
    '-z+1/2,-y+1/2,-x+1/2',&
    '-x,-y,-z',&
    '-z,-x,-y',&
    '-y,-z,-x',&
    'y+1/2,x+1/2,z+1/2',&
    'x+1/2,z+1/2,y+1/2',&
    'z+1/2,y+1/2,x+1/2',&
    '',&
    '*168        C6^1          P6                           P 6',&
    'x,y,z',&
    'x-y,x,z',&
    '-y,x-y,z',&
    '-x,-y,z',&
    '-x+y,-x,z',&
    'y,-x+y,z',&
    '',&
    '*169        C6^2          P61                          P 61',&
    'x,y,z',&
    'x-y,x,z+1/6',&
    '-y,x-y,z+1/3',&
    '-x,-y,z+1/2',&
    '-x+y,-x,z+2/3',&
    'y,-x+y,z+5/6',&
    '',&
    '*170        C6^3          P65                          P 65',&
    'x,y,z',&
    'x-y,x,z+5/6',&
    '-y,x-y,z+2/3',&
    '-x,-y,z+1/2',&
    '-x+y,-x,z+1/3',&
    'y,-x+y,z+1/6',&
    '',&
    '*171        C6^4          P62                          P 62',&
    'x,y,z',&
    'x-y,x,z+1/3',&
    '-y,x-y,z+2/3',&
    '-x,-y,z',&
    '-x+y,-x,z+1/3',&
    'y,-x+y,z+2/3',&
    '',&
    '*172        C6^5          P64                          P 64',&
    'x,y,z',&
    'x-y,x,z+2/3',&
    '-y,x-y,z+1/3',&
    '-x,-y,z',&
    '-x+y,-x,z+2/3',&
    'y,-x+y,z+1/3',&
    '',&
    '*173        C6^6          P63                          P 6c',&
    'x,y,z',&
    'x-y,x,z+1/2',&
    '-y,x-y,z',&
    '-x,-y,z+1/2',&
    '-x+y,-x,z',&
    'y,-x+y,z+1/2',&
    '',&
    '*174        C3h^1         P-6                          P -6',&
    'x,y,z',&
    '-x+y,-x,-z',&
    '-y,x-y,z',&
    'x,y,-z',&
    '-x+y,-x,z',&
    '-y,x-y,-z',&
    '',&
    '*175        C6h^1         P6/m                        -P 6',&
    'x,y,z',&
    'x-y,x,z',&
    '-y,x-y,z',&
    '-x,-y,z',&
    '-x+y,-x,z',&
    'y,-x+y,z',&
    '-x,-y,-z',&
    '-x+y,-x,-z',&
    'y,-x+y,-z',&
    'x,y,-z',&
    'x-y,x,-z',&
    '-y,x-y,-z',&
    '',&
    '*176        C6h^2         P63/m                       -P 6c',&
    'x,y,z',&
    'x-y,x,z+1/2',&
    '-y,x-y,z',&
    '-x,-y,z+1/2',&
    '-x+y,-x,z',&
    'y,-x+y,z+1/2',&
    '-x,-y,-z',&
    '-x+y,-x,-z+1/2',&
    'y,-x+y,-z',&
    'x,y,-z+1/2',&
    'x-y,x,-z',&
    '-y,x-y,-z+1/2',&
    '',&
    '*177        D6^1          P622                         P 6 2',&
    'x,y,z',&
    'x-y,x,z',&
    '-y,x-y,z',&
    '-x,-y,z',&
    '-x+y,-x,z',&
    'y,-x+y,z',&
    'x-y,-y,-z',&
    '-x,-x+y,-z',&
    'y,x,-z',&
    '-y,-x,-z',&
    '-x+y,y,-z',&
    'x,x-y,-z',&
    '',&
    '*178        D6^2          P6122                        P 61 2 (0 0 -1)',&
    'x,y,z',&
    'x-y,x,z+1/6',&
    '-y,x-y,z+1/3',&
    '-x,-y,z+1/2',&
    '-x+y,-x,z+2/3',&
    'y,-x+y,z+5/6',&
    'x-y,-y,-z',&
    '-x,-x+y,-z+2/3',&
    'y,x,-z+1/3',&
    '-y,-x,-z+5/6',&
    '-x+y,y,-z+1/2',&
    'x,x-y,-z+1/6',&
    '',&
    '*179        D6^3          P6522                        P 65 2 (0 0 1)',&
    'x,y,z',&
    'x-y,x,z+5/6',&
    '-y,x-y,z+2/3',&
    '-x,-y,z+1/2',&
    '-x+y,-x,z+1/3',&
    'y,-x+y,z+1/6',&
    'x-y,-y,-z',&
    '-x,-x+y,-z+1/3',&
    'y,x,-z+2/3',&
    '-y,-x,-z+1/6',&
    '-x+y,y,-z+1/2',&
    'x,x-y,-z+5/6',&
    '',&
    '*180        D6^4          P6222                        P 62 2c (0 0 1)',&
    'x,y,z',&
    'x-y,x,z+1/3',&
    '-y,x-y,z+2/3',&
    '-x,-y,z',&
    '-x+y,-x,z+1/3',&
    'y,-x+y,z+2/3',&
    'x-y,-y,-z',&
    '-x,-x+y,-z+1/3',&
    'y,x,-z+2/3',&
    '-y,-x,-z+2/3',&
    '-x+y,y,-z',&
    'x,x-y,-z+1/3',&
    '',&
    '*181        D6^5          P6422                        P 64 2c (0 0 -1)',&
    'x,y,z',&
    'x-y,x,z+2/3',&
    '-y,x-y,z+1/3',&
    '-x,-y,z',&
    '-x+y,-x,z+2/3',&
    'y,-x+y,z+1/3',&
    'x-y,-y,-z',&
    '-x,-x+y,-z+2/3',&
    'y,x,-z+1/3',&
    '-y,-x,-z+1/3',&
    '-x+y,y,-z',&
    'x,x-y,-z+2/3',&
    '',&
    '*182        D6^6          P6322                        P 6c 2c',&
    'x,y,z',&
    'x-y,x,z+1/2',&
    '-y,x-y,z',&
    '-x,-y,z+1/2',&
    '-x+y,-x,z',&
    'y,-x+y,z+1/2',&
    'x-y,-y,-z',&
    '-x,-x+y,-z',&
    'y,x,-z',&
    '-y,-x,-z+1/2',&
    '-x+y,y,-z+1/2',&
    'x,x-y,-z+1/2',&
    '',&
    '*183        C6v^1         P6mm                         P 6 -2',&
    'x,y,z',&
    'x-y,x,z',&
    '-y,x-y,z',&
    '-x,-y,z',&
    '-x+y,-x,z',&
    'y,-x+y,z',&
    '-x+y,y,z',&
    'x,x-y,z',&
    '-y,-x,z',&
    'y,x,z',&
    'x-y,-y,z',&
    '-x,-x+y,z',&
    '',&
    '*184        C6v^2         P6cc                         P 6 -2c',&
    'x,y,z',&
    'x-y,x,z',&
    '-y,x-y,z',&
    '-x,-y,z',&
    '-x+y,-x,z',&
    'y,-x+y,z',&
    '-x+y,y,z+1/2',&
    'x,x-y,z+1/2',&
    '-y,-x,z+1/2',&
    'y,x,z+1/2',&
    'x-y,-y,z+1/2',&
    '-x,-x+y,z+1/2',&
    '',&
    '*185        C6v^3         P63cm                        P 6c -2',&
    'x,y,z',&
    'x-y,x,z+1/2',&
    '-y,x-y,z',&
    '-x,-y,z+1/2',&
    '-x+y,-x,z',&
    'y,-x+y,z+1/2',&
    '-x+y,y,z+1/2',&
    'x,x-y,z+1/2',&
    '-y,-x,z+1/2',&
    'y,x,z',&
    'x-y,-y,z',&
    '-x,-x+y,z',&
    '',&
    '*186        C6v^4         P63mc                        P 6c -2c',&
    'x,y,z',&
    'x-y,x,z+1/2',&
    '-y,x-y,z',&
    '-x,-y,z+1/2',&
    '-x+y,-x,z',&
    'y,-x+y,z+1/2',&
    '-x+y,y,z',&
    'x,x-y,z',&
    '-y,-x,z',&
    'y,x,z+1/2',&
    'x-y,-y,z+1/2',&
    '-x,-x+y,z+1/2',&
    '',&
    '*187        D3h^1         P-6m2                        P -6 2',&
    'x,y,z',&
    '-x+y,-x,-z',&
    '-y,x-y,z',&
    'x,y,-z',&
    '-x+y,-x,z',&
    '-y,x-y,-z',&
    '-y,-x,-z',&
    '-x+y,y,-z',&
    'x,x-y,-z',&
    '-x+y,y,z',&
    'x,x-y,z',&
    '-y,-x,z',&
    '',&
    '*188        D3h^2         P-6c2                        P -6c 2',&
    'x,y,z',&
    '-x+y,-x,-z+1/2',&
    '-y,x-y,z',&
    'x,y,-z+1/2',&
    '-x+y,-x,z',&
    '-y,x-y,-z+1/2',&
    '-y,-x,-z',&
    '-x+y,y,-z',&
    'x,x-y,-z',&
    '-x+y,y,z+1/2',&
    'x,x-y,z+1/2',&
    '-y,-x,z+1/2',&
    '',&
    '*189        D3h^3         P-62m                        P -6 -2',&
    'x,y,z',&
    '-x+y,-x,-z',&
    '-y,x-y,z',&
    'x,y,-z',&
    '-x+y,-x,z',&
    '-y,x-y,-z',&
    'x-y,-y,-z',&
    '-x,-x+y,-z',&
    'y,x,-z',&
    'y,x,z',&
    'x-y,-y,z',&
    '-x,-x+y,z',&
    '',&
    '*190        D3h^4         P-62c                        P -6c -2c',&
    'x,y,z',&
    '-x+y,-x,-z+1/2',&
    '-y,x-y,z',&
    'x,y,-z+1/2',&
    '-x+y,-x,z',&
    '-y,x-y,-z+1/2',&
    'x-y,-y,-z',&
    '-x,-x+y,-z',&
    'y,x,-z',&
    'y,x,z+1/2',&
    'x-y,-y,z+1/2',&
    '-x,-x+y,z+1/2',&
    '',&
    '*191        D6h^1         P6/mmm                      -P 6 2',&
    'x,y,z',&
    'x-y,x,z',&
    '-y,x-y,z',&
    '-x,-y,z',&
    '-x+y,-x,z',&
    'y,-x+y,z',&
    'x-y,-y,-z',&
    '-x,-x+y,-z',&
    'y,x,-z',&
    '-y,-x,-z',&
    '-x+y,y,-z',&
    'x,x-y,-z',&
    '-x,-y,-z',&
    '-x+y,-x,-z',&
    'y,-x+y,-z',&
    'x,y,-z',&
    'x-y,x,-z',&
    '-y,x-y,-z',&
    '-x+y,y,z',&
    'x,x-y,z',&
    '-y,-x,z',&
    'y,x,z',&
    'x-y,-y,z',&
    '-x,-x+y,z',&
    '',&
    '*192        D6h^2         P6/mcc                      -P 6 2c',&
    'x,y,z',&
    'x-y,x,z',&
    '-y,x-y,z',&
    '-x,-y,z',&
    '-x+y,-x,z',&
    'y,-x+y,z',&
    'x-y,-y,-z+1/2',&
    '-x,-x+y,-z+1/2',&
    'y,x,-z+1/2',&
    '-y,-x,-z+1/2',&
    '-x+y,y,-z+1/2',&
    'x,x-y,-z+1/2',&
    '-x,-y,-z',&
    '-x+y,-x,-z',&
    'y,-x+y,-z',&
    'x,y,-z',&
    'x-y,x,-z',&
    '-y,x-y,-z',&
    '-x+y,y,z+1/2',&
    'x,x-y,z+1/2',&
    '-y,-x,z+1/2',&
    'y,x,z+1/2',&
    'x-y,-y,z+1/2',&
    '-x,-x+y,z+1/2',&
    '',&
    '*193        D6h^3         P63/mcm                     -P 6c 2',&
    'x,y,z',&
    'x-y,x,z+1/2',&
    '-y,x-y,z',&
    '-x,-y,z+1/2',&
    '-x+y,-x,z',&
    'y,-x+y,z+1/2',&
    'x-y,-y,-z+1/2',&
    '-x,-x+y,-z+1/2',&
    'y,x,-z+1/2',&
    '-y,-x,-z',&
    '-x+y,y,-z',&
    'x,x-y,-z',&
    '-x,-y,-z',&
    '-x+y,-x,-z+1/2',&
    'y,-x+y,-z',&
    'x,y,-z+1/2',&
    'x-y,x,-z',&
    '-y,x-y,-z+1/2',&
    '-x+y,y,z+1/2',&
    'x,x-y,z+1/2',&
    '-y,-x,z+1/2',&
    'y,x,z',&
    'x-y,-y,z',&
    '-x,-x+y,z',&
    '',&
    '*194        D6h^4         P63/mmc                     -P 6c 2c',&
    'x,y,z',&
    'x-y,x,z+1/2',&
    '-y,x-y,z',&
    '-x,-y,z+1/2',&
    '-x+y,-x,z',&
    'y,-x+y,z+1/2',&
    'x-y,-y,-z',&
    '-x,-x+y,-z',&
    'y,x,-z',&
    '-y,-x,-z+1/2',&
    '-x+y,y,-z+1/2',&
    'x,x-y,-z+1/2',&
    '-x,-y,-z',&
    '-x+y,-x,-z+1/2',&
    'y,-x+y,-z',&
    'x,y,-z+1/2',&
    'x-y,x,-z',&
    '-y,x-y,-z+1/2',&
    '-x+y,y,z',&
    'x,x-y,z',&
    '-y,-x,z',&
    'y,x,z+1/2',&
    'x-y,-y,z+1/2',&
    '-x,-x+y,z+1/2',&
    '',&
    '*195        T^1           P23                          P 2 2 3',&
    'x,y,z',&
    'z,x,y',&
    'y,z,x',&
    '-y,-z,x',&
    'z,-x,-y',&
    '-y,z,-x',&
    '-z,-x,y',&
    '-z,x,-y',&
    'y,-z,-x',&
    '-x,-y,z',&
    'x,-y,-z',&
    '-x,y,-z',&
    '',&
    '*196        T^2           F23                          F 2 2 3',&
    'x,y,z',&
    'z,x,y',&
    'y,z,x',&
    '-y,-z,x',&
    'z,-x,-y',&
    '-y,z,-x',&
    '-z,-x,y',&
    '-z,x,-y',&
    'y,-z,-x',&
    '-x,-y,z',&
    'x,-y,-z',&
    '-x,y,-z',&
    '',&
    '*197        T^3           I23                          I 2 2 3',&
    'x,y,z',&
    'z,x,y',&
    'y,z,x',&
    '-y,-z,x',&
    'z,-x,-y',&
    '-y,z,-x',&
    '-z,-x,y',&
    '-z,x,-y',&
    'y,-z,-x',&
    '-x,-y,z',&
    'x,-y,-z',&
    '-x,y,-z',&
    '',&
    '*198        T^4           P213                         P 2ac 2ab 3',&
    'x,y,z',&
    'z,x,y',&
    'y,z,x',&
    '-y+1/2,-z,x+1/2',&
    'z+1/2,-x+1/2,-y',&
    '-y,z+1/2,-x+1/2',&
    '-z+1/2,-x,y+1/2',&
    '-z,x+1/2,-y+1/2',&
    'y+1/2,-z+1/2,-x',&
    '-x+1/2,-y,z+1/2',&
    'x+1/2,-y+1/2,-z',&
    '-x,y+1/2,-z+1/2',&
    '',&
    '*199        T^5           I213                         I 2b 2c 3',&
    'x,y,z',&
    'z,x,y',&
    'y,z,x',&
    '-y,-z+1/2,x',&
    'z,-x,-y+1/2',&
    '-y+1/2,z,-x',&
    '-z,-x+1/2,y',&
    '-z+1/2,x,-y',&
    'y,-z,-x+1/2',&
    '-x,-y+1/2,z',&
    'x,-y,-z+1/2',&
    '-x+1/2,y,-z',&
    '',&
    '*200        Th^1          Pm-3                        -P 2 2 3',&
    'x,y,z',&
    'z,x,y',&
    'y,z,x',&
    '-y,-z,x',&
    'z,-x,-y',&
    '-y,z,-x',&
    '-z,-x,y',&
    '-z,x,-y',&
    'y,-z,-x',&
    '-x,-y,z',&
    'x,-y,-z',&
    '-x,y,-z',&
    '-x,-y,-z',&
    '-z,-x,-y',&
    '-y,-z,-x',&
    'y,z,-x',&
    '-z,x,y',&
    'y,-z,x',&
    'z,x,-y',&
    'z,-x,y',&
    '-y,z,x',&
    'x,y,-z',&
    '-x,y,z',&
    'x,-y,z',&
    '',&
    '*201:1      Th^2          Pn-3:1                       P 2 2 3 -1n',&
    'x,y,z',&
    '-x+1/2,-y+1/2,-z+1/2',&
    'z,x,y',&
    'y,z,x',&
    '-y,-z,x',&
    'z,-x,-y',&
    '-y,z,-x',&
    '-z,-x,y',&
    '-z,x,-y',&
    'y,-z,-x',&
    '-z+1/2,-x+1/2,-y+1/2',&
    '-y+1/2,-z+1/2,-x+1/2',&
    'y+1/2,z+1/2,-x+1/2',&
    '-z+1/2,x+1/2,y+1/2',&
    'y+1/2,-z+1/2,x+1/2',&
    'z+1/2,x+1/2,-y+1/2',&
    'z+1/2,-x+1/2,y+1/2',&
    '-y+1/2,z+1/2,x+1/2',&
    '-x,-y,z',&
    'x,-y,-z',&
    '-x,y,-z',&
    'x+1/2,y+1/2,-z+1/2',&
    '-x+1/2,y+1/2,z+1/2',&
    'x+1/2,-y+1/2,z+1/2',&
    '',&
    '*201:2      Th^2          Pn-3:2                      -P 2ab 2bc 3',&
    'x,y,z',&
    'z,x,y',&
    'y,z,x',&
    '-y+1/2,-z+1/2,x',&
    'z,-x+1/2,-y+1/2',&
    '-y+1/2,z,-x+1/2',&
    '-z+1/2,-x+1/2,y',&
    '-z+1/2,x,-y+1/2',&
    'y,-z+1/2,-x+1/2',&
    '-x+1/2,-y+1/2,z',&
    'x,-y+1/2,-z+1/2',&
    '-x+1/2,y,-z+1/2',&
    '-x,-y,-z',&
    '-z,-x,-y',&
    '-y,-z,-x',&
    'y+1/2,z+1/2,-x',&
    '-z,x+1/2,y+1/2',&
    'y+1/2,-z,x+1/2',&
    'z+1/2,x+1/2,-y',&
    'z+1/2,-x,y+1/2',&
    '-y,z+1/2,x+1/2',&
    'x+1/2,y+1/2,-z',&
    '-x,y+1/2,z+1/2',&
    'x+1/2,-y,z+1/2',&
    '',&
    '*202        Th^3          Fm-3                        -F 2 2 3',&
    'x,y,z',&
    'z,x,y',&
    'y,z,x',&
    '-y,-z,x',&
    'z,-x,-y',&
    '-y,z,-x',&
    '-z,-x,y',&
    '-z,x,-y',&
    'y,-z,-x',&
    '-x,-y,z',&
    'x,-y,-z',&
    '-x,y,-z',&
    '-x,-y,-z',&
    '-z,-x,-y',&
    '-y,-z,-x',&
    'y,z,-x',&
    '-z,x,y',&
    'y,-z,x',&
    'z,x,-y',&
    'z,-x,y',&
    '-y,z,x',&
    'x,y,-z',&
    '-x,y,z',&
    'x,-y,z',&
    '',&
    '*203:1      Th^4          Fd-3:1                       F 2 2 3 -1d',&
    'x,y,z',&
    '-x+1/4,-y+1/4,-z+1/4',&
    'z,x,y',&
    'y,z,x',&
    '-y,-z,x',&
    'z,-x,-y',&
    '-y,z,-x',&
    '-z,-x,y',&
    '-z,x,-y',&
    'y,-z,-x',&
    '-z+1/4,-x+1/4,-y+1/4',&
    '-y+1/4,-z+1/4,-x+1/4',&
    'y+1/4,z+1/4,-x+1/4',&
    '-z+1/4,x+1/4,y+1/4',&
    'y+1/4,-z+1/4,x+1/4',&
    'z+1/4,x+1/4,-y+1/4',&
    'z+1/4,-x+1/4,y+1/4',&
    '-y+1/4,z+1/4,x+1/4',&
    '-x,-y,z',&
    'x,-y,-z',&
    '-x,y,-z',&
    'x+1/4,y+1/4,-z+1/4',&
    '-x+1/4,y+1/4,z+1/4',&
    'x+1/4,-y+1/4,z+1/4',&
    '',&
    '*203:2      Th^4          Fd-3:2                      -F 2uv 2vw 3',&
    'x,y,z',&
    'z,x,y',&
    'y,z,x',&
    '-y+1/4,-z+1/4,x',&
    'z,-x+1/4,-y+1/4',&
    '-y+1/4,z,-x+1/4',&
    '-z+1/4,-x+1/4,y',&
    '-z+1/4,x,-y+1/4',&
    'y,-z+1/4,-x+1/4',&
    '-x+1/4,-y+1/4,z',&
    'x,-y+1/4,-z+1/4',&
    '-x+1/4,y,-z+1/4',&
    '-x,-y,-z',&
    '-z,-x,-y',&
    '-y,-z,-x',&
    'y+3/4,z+3/4,-x',&
    '-z,x+3/4,y+3/4',&
    'y+3/4,-z,x+3/4',&
    'z+3/4,x+3/4,-y',&
    'z+3/4,-x,y+3/4',&
    '-y,z+3/4,x+3/4',&
    'x+3/4,y+3/4,-z',&
    '-x,y+3/4,z+3/4',&
    'x+3/4,-y,z+3/4',&
    '',&
    '*204        Th^5          Im-3                        -I 2 2 3',&
    'x,y,z',&
    'z,x,y',&
    'y,z,x',&
    '-y,-z,x',&
    'z,-x,-y',&
    '-y,z,-x',&
    '-z,-x,y',&
    '-z,x,-y',&
    'y,-z,-x',&
    '-x,-y,z',&
    'x,-y,-z',&
    '-x,y,-z',&
    '-x,-y,-z',&
    '-z,-x,-y',&
    '-y,-z,-x',&
    'y,z,-x',&
    '-z,x,y',&
    'y,-z,x',&
    'z,x,-y',&
    'z,-x,y',&
    '-y,z,x',&
    'x,y,-z',&
    '-x,y,z',&
    'x,-y,z',&
    '',&
    '*205        Th^6          Pa-3                        -P 2ac 2ab 3',&
    'x,y,z',&
    'z,x,y',&
    'y,z,x',&
    '-y+1/2,-z,x+1/2',&
    'z+1/2,-x+1/2,-y',&
    '-y,z+1/2,-x+1/2',&
    '-z+1/2,-x,y+1/2',&
    '-z,x+1/2,-y+1/2',&
    'y+1/2,-z+1/2,-x',&
    '-x+1/2,-y,z+1/2',&
    'x+1/2,-y+1/2,-z',&
    '-x,y+1/2,-z+1/2',&
    '-x,-y,-z',&
    '-z,-x,-y',&
    '-y,-z,-x',&
    'y+1/2,z,-x+1/2',&
    '-z+1/2,x+1/2,y',&
    'y,-z+1/2,x+1/2',&
    'z+1/2,x,-y+1/2',&
    'z,-x+1/2,y+1/2',&
    '-y+1/2,z+1/2,x',&
    'x+1/2,y,-z+1/2',&
    '-x+1/2,y+1/2,z',&
    'x,-y+1/2,z+1/2',&
    '',&
    '*206        Th^7          Ia-3                        -I 2b 2c 3',&
    'x,y,z',&
    'z,x,y',&
    'y,z,x',&
    '-y,-z+1/2,x',&
    'z,-x,-y+1/2',&
    '-y+1/2,z,-x',&
    '-z,-x+1/2,y',&
    '-z+1/2,x,-y',&
    'y,-z,-x+1/2',&
    '-x,-y+1/2,z',&
    'x,-y,-z+1/2',&
    '-x+1/2,y,-z',&
    '-x,-y,-z',&
    '-z,-x,-y',&
    '-y,-z,-x',&
    'y,z+1/2,-x',&
    '-z,x,y+1/2',&
    'y+1/2,-z,x',&
    'z,x+1/2,-y',&
    'z+1/2,-x,y',&
    '-y,z,x+1/2',&
    'x,y+1/2,-z',&
    '-x,y,z+1/2',&
    'x+1/2,-y,z',&
    '',&
    '*207        O^1           P432                         P 4 2 3',&
    'x,y,z',&
    '-y,x,z',&
    '-x,-y,z',&
    'y,-x,z',&
    'x,-z,y',&
    'x,-y,-z',&
    'x,z,-y',&
    'z,y,-x',&
    '-x,y,-z',&
    '-z,y,x',&
    'z,x,y',&
    'y,z,x',&
    '-y,-z,x',&
    'z,-x,-y',&
    '-y,z,-x',&
    '-z,-x,y',&
    '-z,x,-y',&
    'y,-z,-x',&
    'y,x,-z',&
    '-y,-x,-z',&
    '-x,z,y',&
    '-x,-z,-y',&
    'z,-y,x',&
    '-z,-y,-x',&
    '',&
    '*208        O^2           P4232                        P 4n 2 3',&
    'x,y,z',&
    '-y+1/2,x+1/2,z+1/2',&
    '-x,-y,z',&
    'y+1/2,-x+1/2,z+1/2',&
    'x+1/2,-z+1/2,y+1/2',&
    'x,-y,-z',&
    'x+1/2,z+1/2,-y+1/2',&
    'z+1/2,y+1/2,-x+1/2',&
    '-x,y,-z',&
    '-z+1/2,y+1/2,x+1/2',&
    'z,x,y',&
    'y,z,x',&
    '-y,-z,x',&
    'z,-x,-y',&
    '-y,z,-x',&
    '-z,-x,y',&
    '-z,x,-y',&
    'y,-z,-x',&
    'y+1/2,x+1/2,-z+1/2',&
    '-y+1/2,-x+1/2,-z+1/2',&
    '-x+1/2,z+1/2,y+1/2',&
    '-x+1/2,-z+1/2,-y+1/2',&
    'z+1/2,-y+1/2,x+1/2',&
    '-z+1/2,-y+1/2,-x+1/2',&
    '',&
    '*209        O^3           F432                         F 4 2 3',&
    'x,y,z',&
    '-y,x,z',&
    '-x,-y,z',&
    'y,-x,z',&
    'x,-z,y',&
    'x,-y,-z',&
    'x,z,-y',&
    'z,y,-x',&
    '-x,y,-z',&
    '-z,y,x',&
    'z,x,y',&
    'y,z,x',&
    '-y,-z,x',&
    'z,-x,-y',&
    '-y,z,-x',&
    '-z,-x,y',&
    '-z,x,-y',&
    'y,-z,-x',&
    'y,x,-z',&
    '-y,-x,-z',&
    '-x,z,y',&
    '-x,-z,-y',&
    'z,-y,x',&
    '-z,-y,-x',&
    '',&
    '*210        O^4           F4132                        F 4d 2 3',&
    'x,y,z',&
    '-y+1/4,x+1/4,z+1/4',&
    '-x,-y,z',&
    'y+1/4,-x+1/4,z+1/4',&
    'x+1/4,-z+1/4,y+1/4',&
    'x,-y,-z',&
    'x+1/4,z+1/4,-y+1/4',&
    'z+1/4,y+1/4,-x+1/4',&
    '-x,y,-z',&
    '-z+1/4,y+1/4,x+1/4',&
    'z,x,y',&
    'y,z,x',&
    '-y,-z,x',&
    'z,-x,-y',&
    '-y,z,-x',&
    '-z,-x,y',&
    '-z,x,-y',&
    'y,-z,-x',&
    'y+1/4,x+1/4,-z+1/4',&
    '-y+1/4,-x+1/4,-z+1/4',&
    '-x+1/4,z+1/4,y+1/4',&
    '-x+1/4,-z+1/4,-y+1/4',&
    'z+1/4,-y+1/4,x+1/4',&
    '-z+1/4,-y+1/4,-x+1/4',&
    '',&
    '*211        O^5           I432                         I 4 2 3',&
    'x,y,z',&
    '-y,x,z',&
    '-x,-y,z',&
    'y,-x,z',&
    'x,-z,y',&
    'x,-y,-z',&
    'x,z,-y',&
    'z,y,-x',&
    '-x,y,-z',&
    '-z,y,x',&
    'z,x,y',&
    'y,z,x',&
    '-y,-z,x',&
    'z,-x,-y',&
    '-y,z,-x',&
    '-z,-x,y',&
    '-z,x,-y',&
    'y,-z,-x',&
    'y,x,-z',&
    '-y,-x,-z',&
    '-x,z,y',&
    '-x,-z,-y',&
    'z,-y,x',&
    '-z,-y,-x',&
    '',&
    '*212        O^6           P4332                        P 4acd 2ab 3',&
    'x,y,z',&
    '-y+3/4,x+1/4,z+3/4',&
    '-x+1/2,-y,z+1/2',&
    'y+3/4,-x+3/4,z+1/4',&
    'x+3/4,-z+3/4,y+1/4',&
    'x+1/2,-y+1/2,-z',&
    'x+1/4,z+3/4,-y+3/4',&
    'z+1/4,y+3/4,-x+3/4',&
    '-x,y+1/2,-z+1/2',&
    '-z+3/4,y+1/4,x+3/4',&
    'z,x,y',&
    'y,z,x',&
    '-y+1/2,-z,x+1/2',&
    'z+1/2,-x+1/2,-y',&
    '-y,z+1/2,-x+1/2',&
    '-z+1/2,-x,y+1/2',&
    '-z,x+1/2,-y+1/2',&
    'y+1/2,-z+1/2,-x',&
    'y+1/4,x+3/4,-z+3/4',&
    '-y+1/4,-x+1/4,-z+1/4',&
    '-x+3/4,z+1/4,y+3/4',&
    '-x+1/4,-z+1/4,-y+1/4',&
    'z+3/4,-y+3/4,x+1/4',&
    '-z+1/4,-y+1/4,-x+1/4',&
    '',&
    '*213        O^7           P4132                        P 4bd 2ab 3',&
    'x,y,z',&
    '-y+1/4,x+3/4,z+1/4',&
    '-x+1/2,-y,z+1/2',&
    'y+1/4,-x+1/4,z+3/4',&
    'x+1/4,-z+1/4,y+3/4',&
    'x+1/2,-y+1/2,-z',&
    'x+3/4,z+1/4,-y+1/4',&
    'z+3/4,y+1/4,-x+1/4',&
    '-x,y+1/2,-z+1/2',&
    '-z+1/4,y+3/4,x+1/4',&
    'z,x,y',&
    'y,z,x',&
    '-y+1/2,-z,x+1/2',&
    'z+1/2,-x+1/2,-y',&
    '-y,z+1/2,-x+1/2',&
    '-z+1/2,-x,y+1/2',&
    '-z,x+1/2,-y+1/2',&
    'y+1/2,-z+1/2,-x',&
    'y+3/4,x+1/4,-z+1/4',&
    '-y+3/4,-x+3/4,-z+3/4',&
    '-x+1/4,z+3/4,y+1/4',&
    '-x+3/4,-z+3/4,-y+3/4',&
    'z+1/4,-y+1/4,x+3/4',&
    '-z+3/4,-y+3/4,-x+3/4',&
    '',&
    '*214        O^8           I4132                        I 4bd 2c 3',&
    'x,y,z',&
    '-y+1/4,x+3/4,z+1/4',&
    '-x,-y+1/2,z',&
    'y+1/4,-x+1/4,z+3/4',&
    'x+1/4,-z+1/4,y+3/4',&
    'x,-y,-z+1/2',&
    'x+3/4,z+1/4,-y+1/4',&
    'z+3/4,y+1/4,-x+1/4',&
    '-x+1/2,y,-z',&
    '-z+1/4,y+3/4,x+1/4',&
    'z,x,y',&
    'y,z,x',&
    '-y,-z+1/2,x',&
    'z,-x,-y+1/2',&
    '-y+1/2,z,-x',&
    '-z,-x+1/2,y',&
    '-z+1/2,x,-y',&
    'y,-z,-x+1/2',&
    'y+3/4,x+1/4,-z+1/4',&
    '-y+1/4,-x+1/4,-z+1/4',&
    '-x+1/4,z+3/4,y+1/4',&
    '-x+1/4,-z+1/4,-y+1/4',&
    'z+1/4,-y+1/4,x+3/4',&
    '-z+1/4,-y+1/4,-x+1/4',&
    '',&
    '*215        Td^1          P-43m                        P -4 2 3',&
    'x,y,z',&
    'y,-x,-z',&
    '-x,-y,z',&
    '-y,x,-z',&
    '-x,z,-y',&
    'x,-y,-z',&
    '-x,-z,y',&
    '-z,-y,x',&
    '-x,y,-z',&
    'z,-y,-x',&
    'z,x,y',&
    'y,z,x',&
    '-y,-z,x',&
    'z,-x,-y',&
    '-y,z,-x',&
    '-z,-x,y',&
    '-z,x,-y',&
    'y,-z,-x',&
    '-y,-x,z',&
    'y,x,z',&
    'x,-z,-y',&
    'x,z,y',&
    '-z,y,-x',&
    'z,y,x',&
    '',&
    '*216        Td^2          F-43m                        F -4 2 3',&
    'x,y,z',&
    'y,-x,-z',&
    '-x,-y,z',&
    '-y,x,-z',&
    '-x,z,-y',&
    'x,-y,-z',&
    '-x,-z,y',&
    '-z,-y,x',&
    '-x,y,-z',&
    'z,-y,-x',&
    'z,x,y',&
    'y,z,x',&
    '-y,-z,x',&
    'z,-x,-y',&
    '-y,z,-x',&
    '-z,-x,y',&
    '-z,x,-y',&
    'y,-z,-x',&
    '-y,-x,z',&
    'y,x,z',&
    'x,-z,-y',&
    'x,z,y',&
    '-z,y,-x',&
    'z,y,x',&
    '',&
    '*217        Td^3          I-43m                        I -4 2 3',&
    'x,y,z',&
    'y,-x,-z',&
    '-x,-y,z',&
    '-y,x,-z',&
    '-x,z,-y',&
    'x,-y,-z',&
    '-x,-z,y',&
    '-z,-y,x',&
    '-x,y,-z',&
    'z,-y,-x',&
    'z,x,y',&
    'y,z,x',&
    '-y,-z,x',&
    'z,-x,-y',&
    '-y,z,-x',&
    '-z,-x,y',&
    '-z,x,-y',&
    'y,-z,-x',&
    '-y,-x,z',&
    'y,x,z',&
    'x,-z,-y',&
    'x,z,y',&
    '-z,y,-x',&
    'z,y,x',&
    '',&
    '*218        Td^4          P-43n                        P -4n 2 3',&
    'x,y,z',&
    'y+1/2,-x+1/2,-z+1/2',&
    '-x,-y,z',&
    '-y+1/2,x+1/2,-z+1/2',&
    '-x+1/2,z+1/2,-y+1/2',&
    'x,-y,-z',&
    '-x+1/2,-z+1/2,y+1/2',&
    '-z+1/2,-y+1/2,x+1/2',&
    '-x,y,-z',&
    'z+1/2,-y+1/2,-x+1/2',&
    'z,x,y',&
    'y,z,x',&
    '-y,-z,x',&
    'z,-x,-y',&
    '-y,z,-x',&
    '-z,-x,y',&
    '-z,x,-y',&
    'y,-z,-x',&
    '-y+1/2,-x+1/2,z+1/2',&
    'y+1/2,x+1/2,z+1/2',&
    'x+1/2,-z+1/2,-y+1/2',&
    'x+1/2,z+1/2,y+1/2',&
    '-z+1/2,y+1/2,-x+1/2',&
    'z+1/2,y+1/2,x+1/2',&
    '',&
    '*219        Td^5          F-43c                        F -4c 2 3',&
    'x,y,z',&
    'y,-x,-z+1/2',&
    '-x,-y,z',&
    '-y,x,-z+1/2',&
    '-x,z,-y+1/2',&
    'x,-y,-z',&
    '-x,-z,y+1/2',&
    '-z,-y,x+1/2',&
    '-x,y,-z',&
    'z,-y,-x+1/2',&
    'z,x,y',&
    'y,z,x',&
    '-y,-z,x',&
    'z,-x,-y',&
    '-y,z,-x',&
    '-z,-x,y',&
    '-z,x,-y',&
    'y,-z,-x',&
    '-y,-x,z+1/2',&
    'y,x,z+1/2',&
    'x,-z,-y+1/2',&
    'x,z,y+1/2',&
    '-z,y,-x+1/2',&
    'z,y,x+1/2',&
    '',&
    '*220        Td^6          I-43d                        I -4bd 2c 3',&
    'x,y,z',&
    'y+1/4,-x+3/4,-z+1/4',&
    '-x,-y+1/2,z',&
    '-y+1/4,x+1/4,-z+3/4',&
    '-x+1/4,z+1/4,-y+3/4',&
    'x,-y,-z+1/2',&
    '-x+3/4,-z+1/4,y+1/4',&
    '-z+3/4,-y+1/4,x+1/4',&
    '-x+1/2,y,-z',&
    'z+1/4,-y+3/4,-x+1/4',&
    'z,x,y',&
    'y,z,x',&
    '-y,-z+1/2,x',&
    'z,-x,-y+1/2',&
    '-y+1/2,z,-x',&
    '-z,-x+1/2,y',&
    '-z+1/2,x,-y',&
    'y,-z,-x+1/2',&
    '-y+3/4,-x+1/4,z+1/4',&
    'y+1/4,x+1/4,z+1/4',&
    'x+1/4,-z+3/4,-y+1/4',&
    'x+1/4,z+1/4,y+1/4',&
    '-z+1/4,y+1/4,-x+3/4',&
    'z+1/4,y+1/4,x+1/4',&
    '',&
    '*221        Oh^1          Pm-3m                       -P 4 2 3',&
    'x,y,z',&
    '-y,x,z',&
    '-x,-y,z',&
    'y,-x,z',&
    'x,-z,y',&
    'x,-y,-z',&
    'x,z,-y',&
    'z,y,-x',&
    '-x,y,-z',&
    '-z,y,x',&
    'z,x,y',&
    'y,z,x',&
    '-y,-z,x',&
    'z,-x,-y',&
    '-y,z,-x',&
    '-z,-x,y',&
    '-z,x,-y',&
    'y,-z,-x',&
    'y,x,-z',&
    '-y,-x,-z',&
    '-x,z,y',&
    '-x,-z,-y',&
    'z,-y,x',&
    '-z,-y,-x',&
    '-x,-y,-z',&
    'y,-x,-z',&
    'x,y,-z',&
    '-y,x,-z',&
    '-x,z,-y',&
    '-x,y,z',&
    '-x,-z,y',&
    '-z,-y,x',&
    'x,-y,z',&
    'z,-y,-x',&
    '-z,-x,-y',&
    '-y,-z,-x',&
    'y,z,-x',&
    '-z,x,y',&
    'y,-z,x',&
    'z,x,-y',&
    'z,-x,y',&
    '-y,z,x',&
    '-y,-x,z',&
    'y,x,z',&
    'x,-z,-y',&
    'x,z,y',&
    '-z,y,-x',&
    'z,y,x',&
    '',&
    '*222:1      Oh^2          Pn-3n:1                      P 4 2 3 -1n',&
    'x,y,z',&
    '-x+1/2,-y+1/2,-z+1/2',&
    '-y,x,z',&
    '-x,-y,z',&
    'y,-x,z',&
    'x,-z,y',&
    'x,-y,-z',&
    'x,z,-y',&
    'z,y,-x',&
    '-x,y,-z',&
    '-z,y,x',&
    'y+1/2,-x+1/2,-z+1/2',&
    '-y+1/2,x+1/2,-z+1/2',&
    '-x+1/2,z+1/2,-y+1/2',&
    '-x+1/2,-z+1/2,y+1/2',&
    '-z+1/2,-y+1/2,x+1/2',&
    'z+1/2,-y+1/2,-x+1/2',&
    'z,x,y',&
    'y,z,x',&
    '-y,-z,x',&
    'z,-x,-y',&
    '-y,z,-x',&
    '-z,-x,y',&
    '-z,x,-y',&
    'y,-z,-x',&
    '-z+1/2,-x+1/2,-y+1/2',&
    '-y+1/2,-z+1/2,-x+1/2',&
    'y+1/2,z+1/2,-x+1/2',&
    '-z+1/2,x+1/2,y+1/2',&
    'y+1/2,-z+1/2,x+1/2',&
    'z+1/2,x+1/2,-y+1/2',&
    'z+1/2,-x+1/2,y+1/2',&
    '-y+1/2,z+1/2,x+1/2',&
    'y,x,-z',&
    '-y,-x,-z',&
    '-x,z,y',&
    '-x,-z,-y',&
    'z,-y,x',&
    '-z,-y,-x',&
    'x+1/2,y+1/2,-z+1/2',&
    '-x+1/2,y+1/2,z+1/2',&
    'x+1/2,-y+1/2,z+1/2',&
    '-y+1/2,-x+1/2,z+1/2',&
    'y+1/2,x+1/2,z+1/2',&
    'x+1/2,-z+1/2,-y+1/2',&
    'x+1/2,z+1/2,y+1/2',&
    '-z+1/2,y+1/2,-x+1/2',&
    'z+1/2,y+1/2,x+1/2',&
    '',&
    '*222:2      Oh^2          Pn-3n:2                     -P 4a 2bc 3',&
    'x,y,z',&
    '-y+1/2,x,z',&
    '-x+1/2,-y+1/2,z',&
    'y,-x+1/2,z',&
    'x,-z+1/2,y',&
    'x,-y+1/2,-z+1/2',&
    'x,z,-y+1/2',&
    'z,y,-x+1/2',&
    '-x+1/2,y,-z+1/2',&
    '-z+1/2,y,x',&
    'z,x,y',&
    'y,z,x',&
    '-y+1/2,-z+1/2,x',&
    'z,-x+1/2,-y+1/2',&
    '-y+1/2,z,-x+1/2',&
    '-z+1/2,-x+1/2,y',&
    '-z+1/2,x,-y+1/2',&
    'y,-z+1/2,-x+1/2',&
    'y,x,-z+1/2',&
    '-y+1/2,-x+1/2,-z+1/2',&
    '-x+1/2,z,y',&
    '-x+1/2,-z+1/2,-y+1/2',&
    'z,-y+1/2,x',&
    '-z+1/2,-y+1/2,-x+1/2',&
    '-x,-y,-z',&
    'y+1/2,-x,-z',&
    'x+1/2,y+1/2,-z',&
    '-y,x+1/2,-z',&
    '-x,z+1/2,-y',&
    '-x,y+1/2,z+1/2',&
    '-x,-z,y+1/2',&
    '-z,-y,x+1/2',&
    'x+1/2,-y,z+1/2',&
    'z+1/2,-y,-x',&
    '-z,-x,-y',&
    '-y,-z,-x',&
    'y+1/2,z+1/2,-x',&
    '-z,x+1/2,y+1/2',&
    'y+1/2,-z,x+1/2',&
    'z+1/2,x+1/2,-y',&
    'z+1/2,-x,y+1/2',&
    '-y,z+1/2,x+1/2',&
    '-y,-x,z+1/2',&
    'y+1/2,x+1/2,z+1/2',&
    'x+1/2,-z,-y',&
    'x+1/2,z+1/2,y+1/2',&
    '-z,y+1/2,-x',&
    'z+1/2,y+1/2,x+1/2',&
    '',&
    '*223        Oh^3          Pm-3n                       -P 4n 2 3',&
    'x,y,z',&
    '-y+1/2,x+1/2,z+1/2',&
    '-x,-y,z',&
    'y+1/2,-x+1/2,z+1/2',&
    'x+1/2,-z+1/2,y+1/2',&
    'x,-y,-z',&
    'x+1/2,z+1/2,-y+1/2',&
    'z+1/2,y+1/2,-x+1/2',&
    '-x,y,-z',&
    '-z+1/2,y+1/2,x+1/2',&
    'z,x,y',&
    'y,z,x',&
    '-y,-z,x',&
    'z,-x,-y',&
    '-y,z,-x',&
    '-z,-x,y',&
    '-z,x,-y',&
    'y,-z,-x',&
    'y+1/2,x+1/2,-z+1/2',&
    '-y+1/2,-x+1/2,-z+1/2',&
    '-x+1/2,z+1/2,y+1/2',&
    '-x+1/2,-z+1/2,-y+1/2',&
    'z+1/2,-y+1/2,x+1/2',&
    '-z+1/2,-y+1/2,-x+1/2',&
    '-x,-y,-z',&
    'y+1/2,-x+1/2,-z+1/2',&
    'x,y,-z',&
    '-y+1/2,x+1/2,-z+1/2',&
    '-x+1/2,z+1/2,-y+1/2',&
    '-x,y,z',&
    '-x+1/2,-z+1/2,y+1/2',&
    '-z+1/2,-y+1/2,x+1/2',&
    'x,-y,z',&
    'z+1/2,-y+1/2,-x+1/2',&
    '-z,-x,-y',&
    '-y,-z,-x',&
    'y,z,-x',&
    '-z,x,y',&
    'y,-z,x',&
    'z,x,-y',&
    'z,-x,y',&
    '-y,z,x',&
    '-y+1/2,-x+1/2,z+1/2',&
    'y+1/2,x+1/2,z+1/2',&
    'x+1/2,-z+1/2,-y+1/2',&
    'x+1/2,z+1/2,y+1/2',&
    '-z+1/2,y+1/2,-x+1/2',&
    'z+1/2,y+1/2,x+1/2',&
    '',&
    '*224:1      Oh^4          Pn-3m:1                      P 4n 2 3 -1n',&
    'x,y,z',&
    '-x+1/2,-y+1/2,-z+1/2',&
    '-y+1/2,x+1/2,z+1/2',&
    '-x,-y,z',&
    'y+1/2,-x+1/2,z+1/2',&
    'x+1/2,-z+1/2,y+1/2',&
    'x,-y,-z',&
    'x+1/2,z+1/2,-y+1/2',&
    'z+1/2,y+1/2,-x+1/2',&
    '-x,y,-z',&
    '-z+1/2,y+1/2,x+1/2',&
    'y,-x,-z',&
    '-y,x,-z',&
    '-x,z,-y',&
    '-x,-z,y',&
    '-z,-y,x',&
    'z,-y,-x',&
    'z,x,y',&
    'y,z,x',&
    '-y,-z,x',&
    'z,-x,-y',&
    '-y,z,-x',&
    '-z,-x,y',&
    '-z,x,-y',&
    'y,-z,-x',&
    '-z+1/2,-x+1/2,-y+1/2',&
    '-y+1/2,-z+1/2,-x+1/2',&
    'y+1/2,z+1/2,-x+1/2',&
    '-z+1/2,x+1/2,y+1/2',&
    'y+1/2,-z+1/2,x+1/2',&
    'z+1/2,x+1/2,-y+1/2',&
    'z+1/2,-x+1/2,y+1/2',&
    '-y+1/2,z+1/2,x+1/2',&
    'y+1/2,x+1/2,-z+1/2',&
    '-y+1/2,-x+1/2,-z+1/2',&
    '-x+1/2,z+1/2,y+1/2',&
    '-x+1/2,-z+1/2,-y+1/2',&
    'z+1/2,-y+1/2,x+1/2',&
    '-z+1/2,-y+1/2,-x+1/2',&
    'x+1/2,y+1/2,-z+1/2',&
    '-x+1/2,y+1/2,z+1/2',&
    'x+1/2,-y+1/2,z+1/2',&
    '-y,-x,z',&
    'y,x,z',&
    'x,-z,-y',&
    'x,z,y',&
    '-z,y,-x',&
    'z,y,x',&
    '',&
    '*224:2      Oh^4          Pn-3m:2                     -P 4bc 2bc 3',&
    'x,y,z',&
    '-y,x+1/2,z+1/2',&
    '-x+1/2,-y+1/2,z',&
    'y+1/2,-x,z+1/2',&
    'x+1/2,-z,y+1/2',&
    'x,-y+1/2,-z+1/2',&
    'x+1/2,z+1/2,-y',&
    'z+1/2,y+1/2,-x',&
    '-x+1/2,y,-z+1/2',&
    '-z,y+1/2,x+1/2',&
    'z,x,y',&
    'y,z,x',&
    '-y+1/2,-z+1/2,x',&
    'z,-x+1/2,-y+1/2',&
    '-y+1/2,z,-x+1/2',&
    '-z+1/2,-x+1/2,y',&
    '-z+1/2,x,-y+1/2',&
    'y,-z+1/2,-x+1/2',&
    'y+1/2,x+1/2,-z',&
    '-y,-x,-z',&
    '-x,z+1/2,y+1/2',&
    '-x,-z,-y',&
    'z+1/2,-y,x+1/2',&
    '-z,-y,-x',&
    '-x,-y,-z',&
    'y,-x+1/2,-z+1/2',&
    'x+1/2,y+1/2,-z',&
    '-y+1/2,x,-z+1/2',&
    '-x+1/2,z,-y+1/2',&
    '-x,y+1/2,z+1/2',&
    '-x+1/2,-z+1/2,y',&
    '-z+1/2,-y+1/2,x',&
    'x+1/2,-y,z+1/2',&
    'z,-y+1/2,-x+1/2',&
    '-z,-x,-y',&
    '-y,-z,-x',&
    'y+1/2,z+1/2,-x',&
    '-z,x+1/2,y+1/2',&
    'y+1/2,-z,x+1/2',&
    'z+1/2,x+1/2,-y',&
    'z+1/2,-x,y+1/2',&
    '-y,z+1/2,x+1/2',&
    '-y+1/2,-x+1/2,z',&
    'y,x,z',&
    'x,-z+1/2,-y+1/2',&
    'x,z,y',&
    '-z+1/2,y,-x+1/2',&
    'z,y,x',&
    '',&
    '*225        Oh^5          Fm-3m                       -F 4 2 3',&
    'x,y,z',&
    '-y,x,z',&
    '-x,-y,z',&
    'y,-x,z',&
    'x,-z,y',&
    'x,-y,-z',&
    'x,z,-y',&
    'z,y,-x',&
    '-x,y,-z',&
    '-z,y,x',&
    'z,x,y',&
    'y,z,x',&
    '-y,-z,x',&
    'z,-x,-y',&
    '-y,z,-x',&
    '-z,-x,y',&
    '-z,x,-y',&
    'y,-z,-x',&
    'y,x,-z',&
    '-y,-x,-z',&
    '-x,z,y',&
    '-x,-z,-y',&
    'z,-y,x',&
    '-z,-y,-x',&
    '-x,-y,-z',&
    'y,-x,-z',&
    'x,y,-z',&
    '-y,x,-z',&
    '-x,z,-y',&
    '-x,y,z',&
    '-x,-z,y',&
    '-z,-y,x',&
    'x,-y,z',&
    'z,-y,-x',&
    '-z,-x,-y',&
    '-y,-z,-x',&
    'y,z,-x',&
    '-z,x,y',&
    'y,-z,x',&
    'z,x,-y',&
    'z,-x,y',&
    '-y,z,x',&
    '-y,-x,z',&
    'y,x,z',&
    'x,-z,-y',&
    'x,z,y',&
    '-z,y,-x',&
    'z,y,x',&
    '',&
    '*226        Oh^6          Fm-3c                       -F 4c 2 3',&
    'x,y,z',&
    '-y,x,z+1/2',&
    '-x,-y,z',&
    'y,-x,z+1/2',&
    'x,-z,y+1/2',&
    'x,-y,-z',&
    'x,z,-y+1/2',&
    'z,y,-x+1/2',&
    '-x,y,-z',&
    '-z,y,x+1/2',&
    'z,x,y',&
    'y,z,x',&
    '-y,-z,x',&
    'z,-x,-y',&
    '-y,z,-x',&
    '-z,-x,y',&
    '-z,x,-y',&
    'y,-z,-x',&
    'y,x,-z+1/2',&
    '-y,-x,-z+1/2',&
    '-x,z,y+1/2',&
    '-x,-z,-y+1/2',&
    'z,-y,x+1/2',&
    '-z,-y,-x+1/2',&
    '-x,-y,-z',&
    'y,-x,-z+1/2',&
    'x,y,-z',&
    '-y,x,-z+1/2',&
    '-x,z,-y+1/2',&
    '-x,y,z',&
    '-x,-z,y+1/2',&
    '-z,-y,x+1/2',&
    'x,-y,z',&
    'z,-y,-x+1/2',&
    '-z,-x,-y',&
    '-y,-z,-x',&
    'y,z,-x',&
    '-z,x,y',&
    'y,-z,x',&
    'z,x,-y',&
    'z,-x,y',&
    '-y,z,x',&
    '-y,-x,z+1/2',&
    'y,x,z+1/2',&
    'x,-z,-y+1/2',&
    'x,z,y+1/2',&
    '-z,y,-x+1/2',&
    'z,y,x+1/2',&
    '',&
    '*227:1      Oh^7          Fd-3m:1                      F 4d 2 3 -1d',&
    'x,y,z',&
    '-x+1/4,-y+1/4,-z+1/4',&
    '-y+1/4,x+1/4,z+1/4',&
    '-x,-y,z',&
    'y+1/4,-x+1/4,z+1/4',&
    'x+1/4,-z+1/4,y+1/4',&
    'x,-y,-z',&
    'x+1/4,z+1/4,-y+1/4',&
    'z+1/4,y+1/4,-x+1/4',&
    '-x,y,-z',&
    '-z+1/4,y+1/4,x+1/4',&
    'y,-x,-z',&
    '-y,x,-z',&
    '-x,z,-y',&
    '-x,-z,y',&
    '-z,-y,x',&
    'z,-y,-x',&
    'z,x,y',&
    'y,z,x',&
    '-y,-z,x',&
    'z,-x,-y',&
    '-y,z,-x',&
    '-z,-x,y',&
    '-z,x,-y',&
    'y,-z,-x',&
    '-z+1/4,-x+1/4,-y+1/4',&
    '-y+1/4,-z+1/4,-x+1/4',&
    'y+1/4,z+1/4,-x+1/4',&
    '-z+1/4,x+1/4,y+1/4',&
    'y+1/4,-z+1/4,x+1/4',&
    'z+1/4,x+1/4,-y+1/4',&
    'z+1/4,-x+1/4,y+1/4',&
    '-y+1/4,z+1/4,x+1/4',&
    'y+1/4,x+1/4,-z+1/4',&
    '-y+1/4,-x+1/4,-z+1/4',&
    '-x+1/4,z+1/4,y+1/4',&
    '-x+1/4,-z+1/4,-y+1/4',&
    'z+1/4,-y+1/4,x+1/4',&
    '-z+1/4,-y+1/4,-x+1/4',&
    'x+1/4,y+1/4,-z+1/4',&
    '-x+1/4,y+1/4,z+1/4',&
    'x+1/4,-y+1/4,z+1/4',&
    '-y,-x,z',&
    'y,x,z',&
    'x,-z,-y',&
    'x,z,y',&
    '-z,y,-x',&
    'z,y,x',&
    '',&
    '*227:2      Oh^7          Fd-3m:2                     -F 4vw 2vw 3',&
    'x,y,z',&
    '-y,x+1/4,z+1/4',&
    '-x+1/4,-y+1/4,z',&
    'y+1/4,-x,z+1/4',&
    'x+1/4,-z,y+1/4',&
    'x,-y+1/4,-z+1/4',&
    'x+1/4,z+1/4,-y',&
    'z+1/4,y+1/4,-x',&
    '-x+1/4,y,-z+1/4',&
    '-z,y+1/4,x+1/4',&
    'z,x,y',&
    'y,z,x',&
    '-y+1/4,-z+1/4,x',&
    'z,-x+1/4,-y+1/4',&
    '-y+1/4,z,-x+1/4',&
    '-z+1/4,-x+1/4,y',&
    '-z+1/4,x,-y+1/4',&
    'y,-z+1/4,-x+1/4',&
    'y+1/4,x+1/4,-z',&
    '-y,-x,-z',&
    '-x,z+1/4,y+1/4',&
    '-x,-z,-y',&
    'z+1/4,-y,x+1/4',&
    '-z,-y,-x',&
    '-x,-y,-z',&
    'y,-x+3/4,-z+3/4',&
    'x+3/4,y+3/4,-z',&
    '-y+3/4,x,-z+3/4',&
    '-x+3/4,z,-y+3/4',&
    '-x,y+3/4,z+3/4',&
    '-x+3/4,-z+3/4,y',&
    '-z+3/4,-y+3/4,x',&
    'x+3/4,-y,z+3/4',&
    'z,-y+3/4,-x+3/4',&
    '-z,-x,-y',&
    '-y,-z,-x',&
    'y+3/4,z+3/4,-x',&
    '-z,x+3/4,y+3/4',&
    'y+3/4,-z,x+3/4',&
    'z+3/4,x+3/4,-y',&
    'z+3/4,-x,y+3/4',&
    '-y,z+3/4,x+3/4',&
    '-y+3/4,-x+3/4,z',&
    'y,x,z',&
    'x,-z+3/4,-y+3/4',&
    'x,z,y',&
    '-z+3/4,y,-x+3/4',&
    'z,y,x',&
    '',&
    '*228:1      Oh^8          Fd-3c:1                      F 4d 2 3 -1cd',&
    'x,y,z',&
    '-x+1/4,-y+1/4,-z+3/4',&
    '-y+1/4,x+1/4,z+1/4',&
    '-x,-y,z',&
    'y+1/4,-x+1/4,z+1/4',&
    'x+1/4,-z+1/4,y+1/4',&
    'x,-y,-z',&
    'x+1/4,z+1/4,-y+1/4',&
    'z+1/4,y+1/4,-x+1/4',&
    '-x,y,-z',&
    '-z+1/4,y+1/4,x+1/4',&
    'y,-x,-z+1/2',&
    '-y,x,-z+1/2',&
    '-x,z,-y+1/2',&
    '-x,-z,y+1/2',&
    '-z,-y,x+1/2',&
    'z,-y,-x+1/2',&
    'z,x,y',&
    'y,z,x',&
    '-y,-z,x',&
    'z,-x,-y',&
    '-y,z,-x',&
    '-z,-x,y',&
    '-z,x,-y',&
    'y,-z,-x',&
    '-z+1/4,-x+1/4,-y+3/4',&
    '-y+1/4,-z+1/4,-x+3/4',&
    'y+1/4,z+1/4,-x+3/4',&
    '-z+1/4,x+1/4,y+3/4',&
    'y+1/4,-z+1/4,x+3/4',&
    'z+1/4,x+1/4,-y+3/4',&
    'z+1/4,-x+1/4,y+3/4',&
    '-y+1/4,z+1/4,x+3/4',&
    'y+1/4,x+1/4,-z+1/4',&
    '-y+1/4,-x+1/4,-z+1/4',&
    '-x+1/4,z+1/4,y+1/4',&
    '-x+1/4,-z+1/4,-y+1/4',&
    'z+1/4,-y+1/4,x+1/4',&
    '-z+1/4,-y+1/4,-x+1/4',&
    'x+1/4,y+1/4,-z+3/4',&
    '-x+1/4,y+1/4,z+3/4',&
    'x+1/4,-y+1/4,z+3/4',&
    '-y,-x,z+1/2',&
    'y,x,z+1/2',&
    'x,-z,-y+1/2',&
    'x,z,y+1/2',&
    '-z,y,-x+1/2',&
    'z,y,x+1/2',&
    '',&
    '*228:2      Oh^8          Fd-3c:2                     -F 4cvw 2vw 3',&
    'x,y,z',&
    '-y,x+1/4,z+3/4',&
    '-x+1/4,-y+1/4,z',&
    'y+1/4,-x,z+3/4',&
    'x+1/4,-z,y+3/4',&
    'x,-y+1/4,-z+1/4',&
    'x+1/4,z+3/4,-y',&
    'z+1/4,y+3/4,-x',&
    '-x+1/4,y,-z+1/4',&
    '-z,y+1/4,x+3/4',&
    'z,x,y',&
    'y,z,x',&
    '-y+1/4,-z+1/4,x',&
    'z,-x+1/4,-y+1/4',&
    '-y+1/4,z,-x+1/4',&
    '-z+1/4,-x+1/4,y',&
    '-z+1/4,x,-y+1/4',&
    'y,-z+1/4,-x+1/4',&
    'y+1/4,x+3/4,-z',&
    '-y,-x,-z+1/2',&
    '-x,z+1/4,y+3/4',&
    '-x,-z,-y+1/2',&
    'z+1/4,-y,x+3/4',&
    '-z,-y,-x+1/2',&
    '-x,-y,-z',&
    'y,-x+3/4,-z+1/4',&
    'x+3/4,y+3/4,-z',&
    '-y+3/4,x,-z+1/4',&
    '-x+3/4,z,-y+1/4',&
    '-x,y+3/4,z+3/4',&
    '-x+3/4,-z+1/4,y',&
    '-z+3/4,-y+1/4,x',&
    'x+3/4,-y,z+3/4',&
    'z,-y+3/4,-x+1/4',&
    '-z,-x,-y',&
    '-y,-z,-x',&
    'y+3/4,z+3/4,-x',&
    '-z,x+3/4,y+3/4',&
    'y+3/4,-z,x+3/4',&
    'z+3/4,x+3/4,-y',&
    'z+3/4,-x,y+3/4',&
    '-y,z+3/4,x+3/4',&
    '-y+3/4,-x+1/4,z',&
    'y,x,z+1/2',&
    'x,-z+3/4,-y+1/4',&
    'x,z,y+1/2',&
    '-z+3/4,y,-x+1/4',&
    'z,y,x+1/2',&
    '',&
    '*229        Oh^9          Im-3m                       -I 4 2 3',&
    'x,y,z',&
    '-y,x,z',&
    '-x,-y,z',&
    'y,-x,z',&
    'x,-z,y',&
    'x,-y,-z',&
    'x,z,-y',&
    'z,y,-x',&
    '-x,y,-z',&
    '-z,y,x',&
    'z,x,y',&
    'y,z,x',&
    '-y,-z,x',&
    'z,-x,-y',&
    '-y,z,-x',&
    '-z,-x,y',&
    '-z,x,-y',&
    'y,-z,-x',&
    'y,x,-z',&
    '-y,-x,-z',&
    '-x,z,y',&
    '-x,-z,-y',&
    'z,-y,x',&
    '-z,-y,-x',&
    '-x,-y,-z',&
    'y,-x,-z',&
    'x,y,-z',&
    '-y,x,-z',&
    '-x,z,-y',&
    '-x,y,z',&
    '-x,-z,y',&
    '-z,-y,x',&
    'x,-y,z',&
    'z,-y,-x',&
    '-z,-x,-y',&
    '-y,-z,-x',&
    'y,z,-x',&
    '-z,x,y',&
    'y,-z,x',&
    'z,x,-y',&
    'z,-x,y',&
    '-y,z,x',&
    '-y,-x,z',&
    'y,x,z',&
    'x,-z,-y',&
    'x,z,y',&
    '-z,y,-x',&
    'z,y,x',&
    '',&
    '*230        Oh^10         Ia-3d                       -I 4bd 2c 3',&
    'x,y,z',&
    '-y+1/4,x+3/4,z+1/4',&
    '-x,-y+1/2,z',&
    'y+1/4,-x+1/4,z+3/4',&
    'x+1/4,-z+1/4,y+3/4',&
    'x,-y,-z+1/2',&
    'x+3/4,z+1/4,-y+1/4',&
    'z+3/4,y+1/4,-x+1/4',&
    '-x+1/2,y,-z',&
    '-z+1/4,y+3/4,x+1/4',&
    'z,x,y',&
    'y,z,x',&
    '-y,-z+1/2,x',&
    'z,-x,-y+1/2',&
    '-y+1/2,z,-x',&
    '-z,-x+1/2,y',&
    '-z+1/2,x,-y',&
    'y,-z,-x+1/2',&
    'y+3/4,x+1/4,-z+1/4',&
    '-y+1/4,-x+1/4,-z+1/4',&
    '-x+1/4,z+3/4,y+1/4',&
    '-x+1/4,-z+1/4,-y+1/4',&
    'z+1/4,-y+1/4,x+3/4',&
    '-z+1/4,-y+1/4,-x+1/4',&
    '-x,-y,-z',&
    'y+3/4,-x+1/4,-z+3/4',&
    'x,y+1/2,-z',&
    '-y+3/4,x+3/4,-z+1/4',&
    '-x+3/4,z+3/4,-y+1/4',&
    '-x,y,z+1/2',&
    '-x+1/4,-z+3/4,y+3/4',&
    '-z+1/4,-y+3/4,x+3/4',&
    'x+1/2,-y,z',&
    'z+3/4,-y+1/4,-x+3/4',&
    '-z,-x,-y',&
    '-y,-z,-x',&
    'y,z+1/2,-x',&
    '-z,x,y+1/2',&
    'y+1/2,-z,x',&
    'z,x+1/2,-y',&
    'z+1/2,-x,y',&
    '-y,z,x+1/2',&
    '-y+1/4,-x+3/4,z+3/4',&
    'y+3/4,x+3/4,z+3/4',&
    'x+3/4,-z+1/4,-y+3/4',&
    'x+3/4,z+3/4,y+3/4',&
    '-z+3/4,y+3/4,-x+1/4',&
    'z+3/4,y+3/4,x+3/4'/
end