-- matrixmath.lua
local matrixmath = {}

function matrixmath.transform(pt, mtx)
    tx = {
        mtx[1]*pt[1] + mtx[5]*pt[2] + mtx[9]*pt[3] + mtx[13]*pt[4],
        mtx[2]*pt[1] + mtx[6]*pt[2] + mtx[10]*pt[3] + mtx[14]*pt[4],
        mtx[3]*pt[1] + mtx[7]*pt[2] + mtx[11]*pt[3] + mtx[15]*pt[4],
        mtx[4]*pt[1] + mtx[8]*pt[2] + mtx[12]*pt[3] + mtx[16]*pt[4],
    }
    return tx
end

function matrixmath.make_identity_matrix(m)
    local mtx = {
        1,0,0,0,
        0,1,0,0,
        0,0,1,0,
        0,0,0,1
    }
    for i = 1,16 do
        m[i] = mtx[i]
    end
end

function matrixmath.affine_inverse(m)
    local mtx = {
        m[1], m[5], m[9], 0,
        m[2], m[6], m[10], 0,
        m[3], m[7], m[11], 0,
        0, 0, 0, 1
    }
    local t = {-m[13], -m[14], -m[15], 1}
    t = matrixmath.transform(t, mtx)
    mtx[13] = t[1]
    mtx[14] = t[2]
    mtx[15] = t[3]

    for i=1,16 do
        m[i] = mtx[i]
    end
end

function matrixmath.make_translation_matrix(m, x, y, z)
    matrixmath.make_identity_matrix(m)
    m[13] = x
    m[14] = y
    m[15] = z
end

function matrixmath.make_rotation_matrix(m, theta, x, y, z)
    local len = math.sqrt(x*x + y*y + z*z)
    x = x / len
    y = y / len
    z = z / len

    local c = math.cos(theta)
    local s = math.sin(theta)
    local t = 1 - c

    m[1] = t*x*x + c
    m[2] = t*x*y - s*z
    m[3] = t*x*z + s*y
    m[4] = 0.0

    m[5] = t*x*y + s*z
    m[6] = t*y*y + c
    m[7] = t*y*z - s*x
    m[8] = 0.0

    m[9] = t*x*z - s*y
    m[10] = t*y*z + s*x
    m[11] = t*z*z + c
    m[12] = 0.0

    m[13] = 0.0
    m[14] = 0.0
    m[15] = 0.0
    m[16] = 1.0
end

function matrixmath.make_scale_matrix(m, x, y, z)
    matrixmath.make_identity_matrix(m)
    m[1] = x
    m[6] = y
    m[11] = z
end

-- stores result in a
function matrixmath.pre_multiply(a, b)
    local r = {}
    for i = 1,16 do
        r[i] = 0.0
    end
    for i = 1,16,4 do
        for j = 1,4 do
            r[i+j-1] = -- 1-indexing artifact
                a[i+0] * b[j+0]
              + a[i+1] * b[j+4]
              + a[i+2] * b[j+8]
              + a[i+3] * b[j+12]
        end
    end
    for i = 1,16 do
        a[i] = r[i]
    end
end

-- stores result in a
function matrixmath.post_multiply(a, b)
    local r = {}
    for i = 1,16 do
        r[i] = 0.0
    end
    for i = 1,16,4 do
        for j = 1,4 do
            r[i+j-1] = -- 1-indexing artifact
                b[i+0] * a[j+0]
              + b[i+1] * a[j+4]
              + b[i+2] * a[j+8]
              + b[i+3] * a[j+12]
        end
    end
    for i = 1,16 do
        a[i] = r[i]
    end
end

function matrixmath.glh_translate(m, x, y, z)
    local tx = {}
    matrixmath.make_translation_matrix(tx, x, y, z)
    matrixmath.post_multiply(m, tx)
end

function matrixmath.glh_rotate(m, theta, x, y, z)
    local rx = {}
    matrixmath.make_rotation_matrix(rx, -theta * math.pi/180, x, y, z)
    matrixmath.post_multiply(m, rx)
end

function matrixmath.glh_scale(m, x, y, z)
    local tx = {}
    matrixmath.make_scale_matrix(tx, x, y, z)
    matrixmath.post_multiply(m, tx)
end

function matrixmath.glh_frustum(m, left, right, bottom, top, near, far)
    local temp = 2.0 * near
    local temp2 = right - left
    local temp3 = top - bottom
    local temp4 = far - near

    m[1] = temp / temp2
    m[2] = 0.0
    m[3] = 0.0
    m[4] = 0.0
    m[5] = 0.0
    m[6] = temp / temp3
    m[7] = 0.0
    m[8] = 0.0
    m[9] = (right + left) / temp2
    m[10] = (top + bottom) / temp3
    m[11] = (-far - near) / temp4
    m[12] = -1.0
    m[13] = 0.0
    m[14] = 0.0
    m[15] = (-temp * far) / temp4
    m[16] = 0.0
end

function matrixmath.glh_perspective(m, fov, aspect, near, far)
    local ymax = near * math.tan(fov * math.pi / 360.0)
    local xmax = ymax * aspect
    matrixmath.glh_frustum(m, -xmax, xmax, -ymax, ymax, near, far)
end

function matrixmath.glh_perspective_rh(m, yfov, aspect, znear, zfar)
    matrixmath.make_identity_matrix(m)
    local tan_half_fov = math.tan(yfov * 0.5)
    m[1] = 1.0 / (aspect * tan_half_fov)
    m[6] = 1.0 / tan_half_fov
    m[11] = zfar / (znear - zfar)
    m[12] = -1.0
    m[15] = (zfar * znear) / (znear - zfar)
    m[16] = 0.0
end

function matrixmath.length(v)
    return math.sqrt(v[1]*v[1] + v[2]*v[2] + v[3]*v[3])
end

function matrixmath.normalize(v)
    local length = math.sqrt(v[1]*v[1] + v[2]*v[2] + v[3]*v[3])
    v[1] = v[1] / length
    v[2] = v[2] / length
    v[3] = v[3] / length
end

function matrixmath.cross(a, b)
    local c = {
        a[2]*b[3] - a[3]*b[2],
        a[3]*b[1] - a[1]*b[3],
        a[1]*b[2] - a[2]*b[1]
    }
    return c
end

function matrixmath.glh_lookat(m, eye, center, up)
    for i = 1,16 do
        m[i] = 0.0
    end

    local fwd = {
        center[1] - eye[1],
        center[2] - eye[2],
        center[3] - eye[3],
    }
    matrixmath.normalize(fwd)
    local right = matrixmath.cross(fwd, up)
    matrixmath.normalize(right)
    local up2 = matrixmath.cross(right, fwd)

    m[1] = right[1]
    m[5] = right[2]
    m[9] = right[3]

    m[2] = up2[1]
    m[6] = up2[2]
    m[10] = up2[3]

    m[3] = -fwd[1]
    m[7] = -fwd[2]
    m[11] = -fwd[3]

    m[16] = 1.0
    matrixmath.glh_translate(m, -eye[1], -eye[2], -eye[3])
end

function matrixmath.glh_ortho(m, l, r, b, t, n, f)
    local A = 2 / (r-l)
    local B = 2 / (t-b)
    local C = -2 / (f-n)
    local tx = -(r+l) / (r-l)
    local ty = -(t+b) / (t-b)
    local tz = -(f+n) / (f-n)
    m[1] = A
    m[2] = 0
    m[3] = 0
    m[4] = 0
    m[5] = 0
    m[6] = B
    m[7] = 0
    m[8] = 0
    m[9] = 0
    m[10] = 0
    m[11] = C
    m[12] = 0
    m[13] = tx
    m[14] = ty
    m[15] = tz
    m[16] = 1
end

-- http://www.cg.info.hiroshima-cu.ac.jp/~miyazaki/knowledge/teche52.html
function matrixmath.matrix_to_quat(m)
    q = {
        ( m[1] + m[6] + m[11] + 1) * .25,
        ( m[1] - m[6] - m[11] + 1) * .25,
        (-m[1] + m[6] - m[11] + 1) * .25,
        (-m[1] - m[6] + m[11] + 1) * .25,
    }
    if q[1] < 0 then q[1] = 0 end
    if q[2] < 0 then q[2] = 0 end
    if q[3] < 0 then q[3] = 0 end
    if q[4] < 0 then q[4] = 0 end

    for i=1,4 do
        q[i] = math.sqrt(q[i])
    end
    local SIGN = function(x) if x >= 0 then return 1 else return -1 end end
    if q[1] >= q[2] and q[1] >= q[3] and q[1] >= q[4] then
        q[2] = q[2] * SIGN(m[10]-m[7])
        q[3] = q[3] * SIGN(m[3]-m[9])
        q[4] = q[4] * SIGN(m[5]-m[2])
    elseif q[2] >= q[1] and q[2] >= q[3] and q[2] >= q[4] then
        q[1] = q[1] * SIGN(m[10]-m[7])
        q[3] = q[3] * SIGN(m[5]-m[2])
        q[4] = q[4] * SIGN(m[3]-m[9])
    elseif q[3] >= q[1] and q[3] >= q[2] and q[3] >= q[4] then
        q[1] = q[1] * SIGN(m[3]-m[9])
        q[2] = q[2] * SIGN(m[5]-m[2])
        q[4] = q[4] * SIGN(m[10]-m[7])
    elseif q[4] >= q[1] and q[4] >= q[2] and q[4] >= q[3] then
        q[1] = q[1] * SIGN(m[5]-m[2])
        q[2] = q[2] * SIGN(m[9]-m[3])
        q[3] = q[3] * SIGN(m[10]-m[7])
    else
        print("matrix_to_quat: coding error")
    end
    local NORM = function(a,b,c,d) return math.sqrt(a*a+b*b+c*c+d*d) end
    local r = NORM(q[1], q[2], q[3], q[4])
    for i=1,4 do
        q[i] = q[i] / r
    end
    return q
end

function matrixmath.quat_to_matrix(q)
    m = {}
    matrixmath.make_identity_matrix(m)
    local W = q[1]
    local X = q[2]
    local Y = q[3]
    local Z = q[4]
    local xx = X * X;
    local xy = X * Y;
    local xz = X * Z;
    local xw = X * W;
    local yy = Y * Y;
    local yz = Y * Z;
    local yw = Y * W;
    local zz = Z * Z;
    local zw = Z * W;

    m[1] = 1 - 2 * ( yy + zz );
    m[2] =     2 * ( xy - zw );
    m[3] =     2 * ( xz + yw );

    m[5] =     2 * ( xy + zw );
    m[6] = 1 - 2 * ( xx + zz );
    m[7] =     2 * ( yz - xw );

    m[9]  =     2 * ( xz - yw );
    m[10] =     2 * ( yz + xw );
    m[11] = 1 - 2 * ( xx + yy );

    return m
end

-- https://github.com/grrrwaaa/gct753/blob/master/modules/quat.lua
function matrixmath.matrix_to_quat(m)
    local ux = {m[1], m[5], m[9]}
    local uy = {m[2], m[6], m[10]}
    local uz = {m[3], m[7], m[11]}

    local uxy, uxz = ux[2], ux[3]
    local uyx, uyz = uy[1], uy[3]
    local uzx, uzy = uz[1], uz[2]
    local trace = ux[1] + uy[2] + uz[3]
    
    if trace > 0 then
        local w = math.sqrt(1. + trace)*0.5
        local div = 1/(4*w)
        return {
            (uyz - uzy) * div,
            (uzx - uxz) * div,
            (uxy - uyx) * div,
            w}

    elseif (ux[1] > uy[2] and ux[1] > uz[3]) then
        -- ux.x is greatest
        local x = math.sqrt(1. + ux[1]-uy[2]-uz[3])*0.5
        local div = 1/(4*x)
        return {
            x,
            (uxy + uyx) * div,
            (uxz + uzx) * div,
            (uyz - uzy) * div
        }
    elseif (uy[2] > ux[1] and uy[2] > uz[3]) then
        -- uyx is greatest
        local y = math.sqrt(1. + uy[2]-ux[1]-uz[3])*0.5
        local div = 1/(4*y)
        return {
            (uxy + uyx) * div,
            y,
            (uyz + uzy) * div,
            (uzx - uxz) * div
        }
    else 
        -- uzx is greatest
        local z = math.sqrt(1. + uz[3]-ux[1]-uy[2])*0.5
        local div = 1/(4*z)
        return {
            (uxz + uzx) * div,
            (uyz + uzy) * div,
            z,
            (uxy - uyx) * div
        }
    end
end

function matrixmath.quat_concat(a, b)
    local aw = a[1]
    local ax = a[2]
    local ay = a[3]
    local az = a[4]
    local bw = b[1]
    local bx = b[2]
    local by = b[3]
    local bz = b[4]
    local W = aw*bw - ax*bx - ay*by - az*bz
    local X = aw*bx + ax*bw + ay*bz - az*by
    local Y = aw*by + ay*bw + az*bx - ax*bz
    local Z = aw*bz + az*bw + ax*by - ay*bx
    a[1] = W
    a[2] = X
    a[3] = Y
    a[4] = Z
end

function matrixmath.quat_magnitude(q)
    local w = q[1]
    local x = q[2]
    local y = q[3]
    local z = q[4]
    return math.sqrt(w*w + x*x + y*y + z*z)
end

function matrixmath.quat_normalize(q)
    local mag = matrixmath.quat_magnitude(q)
    for i=1,4 do
        q[i] = q[i] / mag
    end
end

return matrixmath
