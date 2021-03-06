﻿using System;
using System.Linq;
using DevExpress.ExpressApp;

namespace Xpand.Extensions.XAF.ObjectSpaceExtensions {
    public static partial class ObjectSpaceExtensions {
        public static bool Any<T>(this IObjectSpace objectSpace) => objectSpace.GetObjectsQuery<T>().Any();

        public static object NewObject(this IObjectSpace objectSpace,Type type, object key) {
            var o = objectSpace.CreateObject(type);
            objectSpace.TypesInfo.FindTypeInfo(type).KeyMember.SetValue(o, key);
            return o;
        }

        public static T NewObject<T>(this IObjectSpace objectSpace, object key) {
            var o = objectSpace.CreateObject<T>();
            objectSpace.TypesInfo.FindTypeInfo(typeof(T)).KeyMember.SetValue(o, key);
            return o;
        }

        
    }
}