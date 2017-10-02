﻿using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class RotationTransform : Transformation
{
    public Vector3 rotation;

    public override Matrix4x4 Matrix
    {
        get
        {
            float radX = rotation.x * Mathf.Deg2Rad;
            float radY = rotation.y * Mathf.Deg2Rad;
            float radZ = rotation.z * Mathf.Deg2Rad;
            float sinX = Mathf.Sin(radX);
            float sinY = Mathf.Sin(radY);
            float sinZ = Mathf.Sin(radZ);
            float cosX = Mathf.Cos(radX);
            float cosY = Mathf.Cos(radY);
            float cosZ = Mathf.Cos(radZ);

            Matrix4x4 matrix = new Matrix4x4();

            matrix.SetColumn(0, new Vector4(
                cosY * cosZ,
                cosX * sinZ + sinX * sinY * cosZ,
                sinX * sinZ - cosX * sinY * cosZ,
                0
            ));

            matrix.SetColumn(1, new Vector4(
                -cosY * sinZ,
                cosX * cosZ - sinX * sinY * sinZ,
                sinX * cosZ + cosX * sinY * sinZ,
                0
            ));

            matrix.SetColumn(2, new Vector4(
                sinY,
                -sinX * cosY,
                cosX * cosY,
                0
            ));

            matrix.SetColumn(3, new Vector4(0, 0, 0, 1));
            
            return matrix;
        }
    }    
}
