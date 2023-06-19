// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

const int kLeftEyeId = 0;
const int kRightEyeId = 1;
const int kAxisCount = 2;

uint3 _ShadingRateLevels;
uint _HalfWidth; // half of the texture width so that we do computation before shader.
uint _HalfHeight;
int2 _OffsetX; // zero centered offset and 2d because there are 2 eyes.
int2 _OffsetY;
int4 _UpperRightMajorMinorAxes;
int4 _UpperLeftMajorMinorAxes;
int4 _LowerRightMajorMinorAxes;
int4 _LowerLeftMajorMinorAxes;
int4 _BorderUpperRightMajorMinorAxes;
int4 _BorderUpperLeftMajorMinorAxes;
int4 _BorderLowerRightMajorMinorAxes;
int4 _BorderLowerLeftMajorMinorAxes;

// Returns a floating point values <= 1.0 if the given point (coordX, coordY) falls
// within the ellipse given by major and minor axes
float CalculateGeneralizedEllipseLHS(int4 majorMinorAxes, int coordX, int coordY, uint eyeId)
{
    // Calculate the axis indices based on which eye is being used
    const int majorAxisIndex = (eyeId * kAxisCount) + 0;
    const int minorAxisIndex = (eyeId * kAxisCount) + 1;

    // Generalized ellipse eqn: (x-h)^2 / a^2 + (y-k)^2 / b^2 = 1
    const float majorAxisSquared = (float)(majorMinorAxes[majorAxisIndex] * majorMinorAxes[majorAxisIndex]);
    const float minorAxisSquared = (float)(majorMinorAxes[minorAxisIndex] * majorMinorAxes[minorAxisIndex]);
    return ((coordX * coordX) / majorAxisSquared) + ((coordY * coordY) / minorAxisSquared);
}

// Return shading rate level based on input axes for both main and border regions.
// The regions are calculated by calculating if a point is within an ellipse for each quadrant.
uint GetShadingRateLevel(uint3 coords)
{
    const uint eyeId = coords.z;

    const int zeroCenteredCoordX = coords.x - _HalfWidth;
    const int zeroCenteredCoordY = coords.y - _HalfHeight;

    const int offsetZeroCenteredCoordX = zeroCenteredCoordX + _OffsetX[eyeId];
    const int offsetZeroCenteredCoordY = zeroCenteredCoordY + _OffsetY[eyeId];

    float ellipseLHS = 0.0;
    float borderEllipseLHS = 0.0;
    if (offsetZeroCenteredCoordX > 0)
    {
      if (offsetZeroCenteredCoordY > 0)
      {
        ellipseLHS = CalculateGeneralizedEllipseLHS(_UpperRightMajorMinorAxes, offsetZeroCenteredCoordX, offsetZeroCenteredCoordY, eyeId);
        borderEllipseLHS = CalculateGeneralizedEllipseLHS(_BorderUpperRightMajorMinorAxes, offsetZeroCenteredCoordX, offsetZeroCenteredCoordY, eyeId);
      }
      else
      {
        ellipseLHS = CalculateGeneralizedEllipseLHS(_LowerRightMajorMinorAxes, offsetZeroCenteredCoordX, offsetZeroCenteredCoordY, eyeId);
        borderEllipseLHS = CalculateGeneralizedEllipseLHS(_BorderLowerRightMajorMinorAxes, offsetZeroCenteredCoordX, offsetZeroCenteredCoordY, eyeId);
      }
    }
    else
    {
      if (offsetZeroCenteredCoordY > 0)
      {
        ellipseLHS = CalculateGeneralizedEllipseLHS(_UpperLeftMajorMinorAxes, offsetZeroCenteredCoordX, offsetZeroCenteredCoordY, eyeId);
        borderEllipseLHS = CalculateGeneralizedEllipseLHS(_BorderUpperLeftMajorMinorAxes, offsetZeroCenteredCoordX, offsetZeroCenteredCoordY, eyeId);
      }
      else
      {
        ellipseLHS = CalculateGeneralizedEllipseLHS(_LowerLeftMajorMinorAxes, offsetZeroCenteredCoordX, offsetZeroCenteredCoordY, eyeId);
        borderEllipseLHS = CalculateGeneralizedEllipseLHS(_BorderLowerLeftMajorMinorAxes, offsetZeroCenteredCoordX, offsetZeroCenteredCoordY, eyeId);
      }
    }

    uint shadingRateLevel = _ShadingRateLevels[2];
    if (ellipseLHS <= 1.0)
    {
      shadingRateLevel = _ShadingRateLevels[0];
    }
    else if (borderEllipseLHS <= 1.0)
    {
      shadingRateLevel = _ShadingRateLevels[1];
    }
    return shadingRateLevel;
}
